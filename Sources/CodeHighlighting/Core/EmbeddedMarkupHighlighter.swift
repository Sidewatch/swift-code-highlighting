//
//  EmbeddedMarkupHighlighter.swift
//  SwiftCodeHighlighting
//
//  Single-file-component highlighting (Astro / Vue / Svelte): splits the
//  document into markup and embedded-language regions, then paints each region
//  with the best highlighter available for *that* language.
//
//  Created by David Sherlock on 7/30/26.
//

import AppKit
import CodeLanguage

/// Highlighter for single-file components — `.astro`, `.vue`, `.svelte` — whose
/// bodies are several languages stacked in one file.
///
/// None of the three has a bundled tree-sitter grammar, so they used to fall
/// through to one flat ``SyntaxHighlighter`` rule table applied to the whole
/// document. That table can only describe one language at a time, so it was
/// written for the markup — leaving `<style>` bodies almost entirely uncolored
/// and, worse, occasionally *mis*colored: the markup table's JS keyword list
/// painted the `in` of `color-mix(in srgb, …)` as a keyword, because as far as
/// the table was concerned there was no CSS in the file at all.
///
/// This type restores the layering the languages actually have:
///
/// - Astro frontmatter (the leading `---` fence) → TypeScript
/// - `<script>` bodies → TypeScript/JavaScript/JSON (per `lang=` / `type=`)
/// - `<style>` bodies → CSS/SCSS/Sass/Less (per `lang=`)
/// - everything else → the host language's markup rules
///
/// Each embedded region is parsed by its own tree-sitter grammar where one is
/// bundled (CSS, JS, TS, JSON all are) via the same combined-parse machinery
/// injections use — so the region is parsed *in place* and capture ranges are
/// already in document coordinates. Regions whose language has no grammar
/// (SCSS/Sass/Less, which route around the CSS grammar deliberately — see the
/// note by that case in ``SyntaxHighlighter``) fall back to that language's own
/// regex table, which is still far better than the markup table.
///
/// - Note: Like the other tiers, only `.foregroundColor` is ever written, and
///   painting must happen on the main thread (tree-sitter's resolving query
///   cursor is main-actor-isolated).
/// - Note: Region scanning is a full-document string scan per highlight pass,
///   matching what the injection pass already costs for HTML/PHP. SFCs are
///   small by construction, so this is not the huge-file case.
public final class EmbeddedMarkupHighlighter: CodeHighlighter {

    /// An embedded span of a non-markup language: the body range (tag/fence
    /// delimiters excluded) and the language to paint it with.
    public struct Region {
        public let range: NSRange
        public let language: Language
    }

    /// The host SFC language (drives frontmatter handling and `<script>`'s
    /// default dialect).
    private let language: Language

    /// Rules for the markup between the embedded regions — the host language's
    /// existing table.
    private let markup: SyntaxHighlighter

    private let colors: TokenColorProviding

    /// Regex tables for embedded languages with no bundled grammar, built on
    /// first use. Main-thread only, like every other paint path here.
    private var fallbacks: [Language: SyntaxHighlighter] = [:]

    /// Whether `language` is a single-file-component format this handles.
    /// Hosts should try this tier between ``TreeSitterHighlighter`` and the
    /// plain ``SyntaxHighlighter``.
    public static func supports(_ language: Language) -> Bool {
        switch language {
        case .astro, .vue, .svelte: return true
        default: return false
        }
    }

    /// Creates a highlighter for an SFC `language`, or nil for anything
    /// ``supports(_:)`` rejects — so a host can chain it with `??`.
    public init?(language: Language, colors: TokenColorProviding) {
        guard Self.supports(language) else { return nil }
        self.language = language
        self.colors = colors
        self.markup = SyntaxHighlighter(language: language, colors: colors)
    }

    // MARK: - Painting

    @MainActor
    public func highlight(_ storage: NSTextStorage, in editedRange: NSRange) {
        let ns = storage.string as NSString
        guard ns.length > 0 else { return }
        let full = NSRange(location: 0, length: ns.length)

        // Expand to whole lines and clamp exactly like the other two tiers: the
        // three are interchangeable, so a stale range safe against one must not
        // crash the others.
        let lo = ns.lineRange(for: NSRange(location: min(editedRange.location, ns.length), length: 0))
        let hi = ns.lineRange(for: NSRange(location: min(NSMaxRange(editedRange), ns.length), length: 0))
        let clip = NSIntersectionRange(lo.union(hi), full)
        guard clip.length > 0 else { return }

        // One reset for the whole clip, then every region paints over its own
        // slice — markup and embedded spans are disjoint, so order between them
        // doesn't matter and neither can erase the other.
        storage.addAttribute(.foregroundColor, value: colors.foreground, range: clip)

        var painted: [NSRange] = []
        for region in Self.regions(in: ns, language: language) {
            let visible = NSIntersectionRange(region.range, clip)
            guard visible.length > 0 else { continue }
            painted.append(region.range)
            paint(region.language, storage: storage, ns: ns, body: region.range, clip: visible)
        }

        // The markup is whatever the embedded regions left over.
        for gap in Self.complement(of: painted, within: clip) {
            markup.paint(storage, in: gap)
        }
    }

    /// Paints one embedded region. `body` is the region's full extent (the
    /// parser needs all of it for a valid parse even when only part is on
    /// screen); `clip` is the visible slice actually recolored.
    @MainActor
    private func paint(_ lang: Language, storage: NSTextStorage, ns: NSString, body: NSRange, clip: NSRange) {
        if let grammar = TreeSitterHighlighter.grammar(for: lang),
           let tree = TreeSitterHighlighter.combinedParse(grammar, ns: ns, ranges: [body]) {
            // `combinedParse` restricts the parser to `body` via includedRanges,
            // so capture ranges come back in document coordinates already —
            // offset stays 0, exactly as in the injection pass.
            var base = 0
            var hits = TreeSitterHighlighter.collectHits(grammar.highlights, tree: tree, source: ns,
                                                         offset: 0, clip: clip, nextBase: &base)
            hits += TreeSitterHighlighter.collectInjectionHits(grammar, tree: tree, source: ns,
                                                               offset: 0, clip: clip, depth: 0,
                                                               nextBase: &base)
            TreeSitterHighlighter.applyResolved(hits: hits, clip: clip,
                                                defaultColor: colors.foreground, into: storage)
            return
        }
        fallback(for: lang).paint(storage, in: clip)
    }

    /// The regex table for an embedded language with no bundled grammar.
    private func fallback(for lang: Language) -> SyntaxHighlighter {
        if let h = fallbacks[lang] { return h }
        let h = SyntaxHighlighter(language: lang, colors: colors)
        fallbacks[lang] = h
        return h
    }

    // MARK: - Region scanning

    /// Every embedded-language region in `ns`, ascending and non-overlapping.
    /// Public so hosts can report the split (see `--dump-captures`).
    public static func regions(in ns: NSString, language: Language) -> [Region] {
        var out: [Region] = []
        var scanFrom = 0

        // Astro's frontmatter is TypeScript. Scan tags only *after* it, so a
        // `<style>` mentioned in a frontmatter string can't open a fake region.
        if language == .astro, let fence = frontmatter(in: ns) {
            if fence.body.length > 0 { out.append(Region(range: fence.body, language: .typescript)) }
            scanFrom = fence.end
        }

        out += tagRegions(in: ns, from: scanFrom, host: language)
        return out
    }

    /// The leading `---` fence: the range between the fences, and the offset
    /// just past the closing fence line. Nil when the file doesn't open with one.
    private static func frontmatter(in ns: NSString) -> (body: NSRange, end: Int)? {
        guard ns.length >= 3 else { return nil }
        let opening = ns.lineRange(for: NSRange(location: 0, length: 0))
        guard ns.substring(with: opening).trimmed == "---" else { return nil }

        var loc = NSMaxRange(opening)
        while loc < ns.length {
            let line = ns.lineRange(for: NSRange(location: loc, length: 0))
            guard line.length > 0 else { break }   // no forward progress; bail rather than spin
            if ns.substring(with: line).trimmed == "---" {
                let start = NSMaxRange(opening)
                return (NSRange(location: start, length: line.location - start), NSMaxRange(line))
            }
            loc = NSMaxRange(line)
        }
        return nil   // unterminated fence: treat the whole file as markup
    }

    /// Opening `<script …>` / `<style …>` tags. Attributes can't contain `>`,
    /// which is what bounds the match.
    private static let openTag = try? NSRegularExpression(
        pattern: "<(script|style)\\b([^>]*)>", options: [.caseInsensitive])

    /// Attribute pairs inside an opening tag, value quoted or bare.
    private static let attribute = try? NSRegularExpression(
        pattern: "([a-zA-Z_:][\\w:.-]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", options: [])

    /// `<script>`/`<style>` bodies from `start` onward.
    private static func tagRegions(in ns: NSString, from start: Int, host: Language) -> [Region] {
        guard let openTag, start < ns.length else { return [] }
        let text = ns as String
        var out: [Region] = []
        var scanFrom = start

        while scanFrom < ns.length,
              let match = openTag.firstMatch(in: text, options: [],
                                             range: NSRange(location: scanFrom, length: ns.length - scanFrom)) {
            let name = ns.substring(with: match.range(at: 1)).lowercased()
            let attrs = match.range(at: 2).location == NSNotFound ? "" : ns.substring(with: match.range(at: 2))
            let bodyStart = NSMaxRange(match.range)

            // `<script src="…" />` — self-closing, so there is no body and no
            // close tag to skip past.
            if attrs.hasSuffix("/") {
                scanFrom = bodyStart
                continue
            }

            // First close tag wins, exactly as an HTML tokenizer would treat it.
            let closing = ns.range(of: "</\(name)", options: .caseInsensitive,
                                   range: NSRange(location: bodyStart, length: ns.length - bodyStart))
            let bodyEnd = closing.location == NSNotFound ? ns.length : closing.location

            if bodyEnd > bodyStart, let lang = embeddedLanguage(tag: name, attributes: attrs, host: host) {
                out.append(Region(range: NSRange(location: bodyStart, length: bodyEnd - bodyStart), language: lang))
            }
            scanFrom = closing.location == NSNotFound ? ns.length : NSMaxRange(closing)
        }
        return out
    }

    /// The language a `<script>`/`<style>` body is written in. Nil means "leave
    /// it to the markup rules" — a dialect with neither a grammar nor a regex
    /// table of its own.
    private static func embeddedLanguage(tag: String, attributes: String, host: Language) -> Language? {
        let attrs = parseAttributes(attributes)
        let lang = (attrs["lang"] ?? attrs["type"] ?? "").lowercased()

        if tag == "style" {
            switch lang {
            case "scss":            return .scss
            case "sass":            return .sass
            case "less":            return .less
            case "stylus", "styl":  return nil
            default:                return .css     // incl. postcss, text/css, unset
            }
        }

        // JSON payload blocks (`type="application/ld+json"`, import maps, …).
        if lang.contains("json") { return .json }

        switch lang {
        case "ts", "typescript", "text/typescript": return .typescript
        case "js", "jsx", "javascript", "text/javascript", "module", "":
            // Astro compiles bare `<script>` as TypeScript; Vue/Svelte need an
            // explicit `lang="ts"`. TS is a JS superset either way, so an
            // unannotated script parses identically under both.
            return lang.isEmpty && host == .astro ? .typescript : .javascript
        default:
            return .javascript
        }
    }

    /// Attribute name → value for one opening tag's attribute text.
    private static func parseAttributes(_ source: String) -> [String: String] {
        guard let attribute, !source.isEmpty else { return [:] }
        let ns = source as NSString
        var out: [String: String] = [:]
        attribute.enumerateMatches(in: source, options: [],
                                   range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            let name = ns.substring(with: match.range(at: 1)).lowercased()
            for group in 2...4 where match.range(at: group).location != NSNotFound {
                out[name] = ns.substring(with: match.range(at: group))
                break
            }
        }
        return out
    }

    /// The parts of `clip` not covered by `covered` — i.e. the markup spans.
    static func complement(of covered: [NSRange], within clip: NSRange) -> [NSRange] {
        var gaps: [NSRange] = []
        var cursor = clip.location
        for range in TreeSitterHighlighter.mergeAscending(covered) {
            let r = NSIntersectionRange(range, clip)
            guard r.length > 0 else { continue }
            if r.location > cursor { gaps.append(NSRange(location: cursor, length: r.location - cursor)) }
            cursor = max(cursor, NSMaxRange(r))
        }
        if cursor < NSMaxRange(clip) { gaps.append(NSRange(location: cursor, length: NSMaxRange(clip) - cursor)) }
        return gaps
    }
}
