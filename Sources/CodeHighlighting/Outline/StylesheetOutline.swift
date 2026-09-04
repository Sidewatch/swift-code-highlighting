import Foundation
import CodeLanguage

/// Outlines a stylesheet the way its author structured it: the `/* Section */`
/// banner comments become headings and the rules under each nest beneath them,
/// so a WordPress `common.css` reads as "Widgets › Nav Menus › Responsive
/// Component" instead of six thousand lines of rules. CSS has no tree-sitter
/// symbol query — a selector is not a definition — so, like Markdown, this is a
/// hand walk over the text.
///
/// What counts:
/// - **Section** — a block comment that starts its own line at the top level
///   (outside every `{}`), whose text, with edge decoration stripped (`*` `-`
///   `=` `#` `~` `_` and whitespace) and inner whitespace collapsed, is 1…60
///   characters holding none of `{` `}` `;`. That
///   admits `/* Widgets */`, `/* ===== Header ===== */` and WordPress core's
///   multi-line `2.0 - Header` banners; it rejects prose paragraphs,
///   `/*! license */` headers, tool pragmas (`stylelint-…`, `rtl:…`) and code
///   samples. A section's scope runs to the next section or the end.
/// - **Section, SCSS/Less style** — a block of own-line `//` comments holding a
///   decoration row, a title and (usually) a closing row: `// ----` /
///   `// Grid Units` / `// ----`. A lone `// Label` directly above code counts
///   too; a multi-line prose block never does (see ``lineCommentBanners``).
/// - **Variable** — a top-level `$name: value;` (SCSS) or `@name: value;` (Less):
///   the entire content of a tokens or variables partial, nested under its
///   section. Inside a block it is a local and stays out.
/// - **Rule** — a `selector {` prelude at the top level, or directly inside a
///   listed at-rule block. The name is the prelude with whitespace collapsed.
/// - **At-rule with a block** — `@media`, `@supports`, `@layer`, `@container`,
///   `@keyframes`, `@font-face`, `@mixin`, `@function`… — a node whose scope is
///   its block, so the rules inside nest under it. `@mixin` / `@function` read
///   as functions, the rest as modules.
///
/// Strings and comments are skipped, so a `{` in `content: "{"` never opens a
/// block and a `;` inside a quoted `url("data:…")` never ends a prelude. CSS,
/// SCSS and Less; the latter two's `//` line comments are skipped too.
public enum StylesheetOutline {

    /// The languages this outline serves. Sass's indented syntax has no braces to
    /// walk and is deliberately not claimed.
    public static func supports(_ language: Language) -> Bool {
        language == .css || language == .scss || language == .less
    }

    /// Above this many selectors the outline lists sections and at-rules only: a
    /// map with three thousand entries is not a map, and a minified file would put
    /// every one of them on line 1.
    public static let selectorLimit = 1_500

    /// Comment texts that are instructions to tools, not sections.
    private static let pragmaPrefixes = ["rtl:", "stylelint", "prettier", "eslint", "csslint", "postcss", "autoprefixer", "@"]

    /// The at-rules whose block contains rules (which then nest beneath them).
    static let nestingAtRules = ["@media", "@supports", "@layer", "@container", "@scope", "@document"]

    public static func symbols(in text: String, language: Language) -> [Symbol] {
        var scanner = StylesheetScanner(text as NSString, lineComments: language != .css)
        scanner.scan()
        var rules = scanner.rules
        // A map with thousands of entries is not a map: past the limit keep the structure
        // (sections, at-rules) and drop the selectors.
        if rules.filter({ $0.kind == .selector }).count > selectorLimit { rules.removeAll { $0.kind == .selector } }
        let banners = scanner.banners
        var out: [Symbol] = []
        out.reserveCapacity(banners.count + rules.count)
        for (k, b) in banners.enumerated() {
            let end = k + 1 < banners.count ? banners[k + 1].location : scanner.length
            out.append(Symbol(name: b.name, kind: .heading, range: NSRange(location: b.location, length: b.length), line: b.line,
                              scopeRange: NSRange(location: b.location, length: max(b.length, end - b.location))))
        }
        for r in rules {
            out.append(Symbol(name: r.name, kind: r.kind, range: NSRange(location: r.location, length: r.length), line: r.line,
                              scopeRange: r.scopeEnd.map { NSRange(location: r.location, length: $0 - r.location) }))
        }
        return out.sorted { $0.range.location < $1.range.location }
    }

    /// The prelude's text with the comment ranges inside it removed.
    static func preludeText(_ raw: NSRange, cutting comments: [NSRange], in ns: NSString) -> String {
        guard !comments.isEmpty else { return ns.substring(with: raw) }
        var pieces: [String] = []
        var cursor = raw.location
        for c in comments.sorted(by: { $0.location < $1.location }) where NSMaxRange(c) > raw.location {
            let cut = NSIntersectionRange(c, raw)
            if cut.location > cursor { pieces.append(ns.substring(with: NSRange(location: cursor, length: cut.location - cursor))) }
            cursor = max(cursor, NSMaxRange(cut))
        }
        if cursor < NSMaxRange(raw) { pieces.append(ns.substring(with: NSRange(location: cursor, length: NSMaxRange(raw) - cursor))) }
        return pieces.joined(separator: " ")
    }

    /// The banners in one block of consecutive own-line `//` comments (`rows` are the
    /// texts after `//`, in order). Two shapes count:
    /// - **Decorated**: a decoration row (`----`, `====`, `****`…, three or more), a
    ///   title line, and optionally a closing decoration row — the SCSS convention.
    ///   The title must pass ``bannerName(_:)``; prose after the closing row is not
    ///   a title, and a trailing decoration row with nothing under it opens nothing.
    /// - **Lone label**: a block of exactly one line that passes ``bannerName(_:)``
    ///   and sits directly above code (`// Buttons` then `.btn {`). A multi-line
    ///   prose block is never a banner, however short its lines.
    static func lineCommentBanners(_ rows: [(text: String, location: Int, line: Int)], nextIsCode: Bool)
        -> [(name: String, location: Int, length: Int, line: Int)] {
        func isDecorationRow(_ s: String) -> Bool {
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.count >= 3 && t.allSatisfy { "*-=#~_".contains($0) }
        }
        func length(from a: Int, through b: Int) -> Int {
            rows[b].location + (rows[b].text as NSString).length + 2 - rows[a].location
        }
        if rows.count == 1 {
            guard nextIsCode, !isDecorationRow(rows[0].text), let name = bannerName(rows[0].text) else { return [] }
            return [(name, rows[0].location, length(from: 0, through: 0), rows[0].line)]
        }
        var out: [(name: String, location: Int, length: Int, line: Int)] = []
        var k = 0
        while k < rows.count {
            guard isDecorationRow(rows[k].text) else { k += 1; continue }
            if k + 1 < rows.count, !isDecorationRow(rows[k + 1].text), let name = bannerName(rows[k + 1].text) {
                let end = (k + 2 < rows.count && isDecorationRow(rows[k + 2].text)) ? k + 2 : k + 1
                out.append((name, rows[k].location, length(from: k, through: end), rows[k].line))
                k = end + 1
            } else {
                k += 1
            }
        }
        return out
    }

    /// `$name` / `@name` when `prelude` is a variable declaration (`$grid-unit-05: 4px`,
    /// `@brand: #fff`), else nil — `@import 'x'` and `@media …` have no `:` after the name.
    static func variableName(in prelude: String) -> String? {
        guard let first = prelude.first, first == "$" || first == "@" else { return nil }
        var name = String(first)
        var rest = prelude.dropFirst()
        while let ch = rest.first, ch.isLetter || ch.isNumber || ch == "_" || ch == "-" {
            name.append(ch); rest = rest.dropFirst()
        }
        guard name.count > 1 else { return nil }
        while let ch = rest.first, ch == " " || ch == "\t" { rest = rest.dropFirst() }
        return rest.first == ":" ? name : nil
    }

    /// The section name a comment body yields, or nil when the comment is not a
    /// banner (see the type doc for the rule).
    static func bannerName(_ body: String) -> String? {
        let trimmed = body.trimmed
        guard !trimmed.hasPrefix("!") else { return nil }          // `/*! preserved */`
        // Decoration lives at the EDGES of every banner shape seen in the wild —
        // `===== Header =====`, the `-----` rows of a WordPress multi-line banner,
        // the `*` gutter of a `/** … */` block — so edge trimming is the whole
        // rule; a `-` inside "2.0 - Header" is punctuation and stays.
        let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "*-=#~_ \t\r\n"))
        let name = stripped.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map { String($0) }.joined(separator: " ")
        guard (1...60).contains(name.count),
              !name.contains("{"), !name.contains("}"), !name.contains(";") else { return nil }
        let lower = name.lowercased()
        guard !pragmaPrefixes.contains(where: { lower.hasPrefix($0) }) else { return nil }
        return name
    }
}
