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
    private static let nestingAtRules = ["@media", "@supports", "@layer", "@container", "@scope", "@document"]

    public static func symbols(in text: String, language: Language) -> [Symbol] {
        let ns = text as NSString
        let n = ns.length
        var buf = [unichar](repeating: 0, count: n)
        if n > 0 { ns.getCharacters(&buf, range: NSRange(location: 0, length: n)) }
        let lineComments = language != .css

        struct Banner { let name: String; let location: Int; let length: Int; let line: Int }
        struct Rule {
            let name: String; let location: Int; let length: Int; let line: Int
            let kind: SymbolKind; var scopeEnd: Int?
        }
        var banners: [Banner] = []
        var rules: [Rule] = []

        var i = 0
        var line = 1
        var lineStart = 0
        var depth = 0
        /// Per open brace: the index in `rules` of the listed at-rule it opened, or
        /// nil for a plain rule's block (whose contents are never listed).
        var blockStack: [Int?] = []
        /// Where the current prelude began (after the last `;` `{` `}`), and the
        /// comment ranges inside it to cut out of its name.
        var preludeStart = 0
        var preludeComments: [NSRange] = []

        func isWS(_ c: unichar) -> Bool { c == 0x20 || c == 0x09 || c == 0x0D || c == 0x0A }
        func isBlank(_ from: Int, _ to: Int) -> Bool {
            var k = from
            while k < to { if !isWS(buf[k]) { return false }; k += 1 }
            return true
        }
        func newlines(_ from: Int, _ to: Int) -> Int {
            var count = 0, k = from
            while k < to { if buf[k] == 0x0A { count += 1 }; k += 1 }
            return count
        }
        func collapsed(_ s: String) -> String {
            s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        }

        while i < n {
            let c = buf[i]
            if c == 0x0A { line += 1; i += 1; lineStart = i; continue }

            // Block comment — a section candidate when it starts its own top-level line.
            if c == 0x2F, i + 1 < n, buf[i + 1] == 0x2A {
                let start = i
                let startLine = line
                var j = i + 2
                var lastNewline: Int? = nil
                while j + 1 < n, !(buf[j] == 0x2A && buf[j + 1] == 0x2F) {
                    if buf[j] == 0x0A { line += 1; lastNewline = j }
                    j += 1
                }
                let end = j + 1 < n ? j + 2 : n
                if depth == 0, isBlank(lineStart, start),
                   let name = bannerName(ns.substring(with: NSRange(location: start + 2, length: max(0, j - start - 2)))) {
                    banners.append(Banner(name: name, location: start, length: end - start, line: startLine))
                }
                preludeComments.append(NSRange(location: start, length: end - start))
                if let lastNewline { lineStart = lastNewline + 1 }
                i = end
                continue
            }
            // `//` line comment (SCSS / Less).
            if lineComments, c == 0x2F, i + 1 < n, buf[i + 1] == 0x2F {
                let start = i
                while i < n, buf[i] != 0x0A { i += 1 }
                preludeComments.append(NSRange(location: start, length: i - start))
                continue
            }
            // Strings: nothing inside one opens, closes or ends anything.
            if c == 0x22 || c == 0x27 {
                var j = i + 1
                while j < n, buf[j] != c {
                    if buf[j] == 0x5C { j += 1 }                     // escaped char
                    if j < n, buf[j] == 0x0A { line += 1; lineStart = j + 1 }
                    j += 1
                }
                i = min(n, j + 1)
                continue
            }

            switch c {
            case 0x7B: // {
                let raw = NSRange(location: preludeStart, length: i - preludeStart)
                let name = collapsed(preludeText(raw, cutting: preludeComments, in: ns))
                var listed: Int? = nil
                if !name.isEmpty, depth == 0 || blockStack.last! != nil {
                    var nameStart = preludeStart
                    while nameStart < i, isWS(buf[nameStart]) || preludeComments.contains(where: { NSLocationInRange(nameStart, $0) }) { nameStart += 1 }
                    let isAtRule = name.hasPrefix("@")
                    let kind: SymbolKind = isAtRule
                        ? (name.hasPrefix("@mixin") || name.hasPrefix("@function") ? .function : .module)
                        : .selector
                    rules.append(Rule(name: name, location: nameStart, length: max(1, i - nameStart),
                                      line: line - newlines(nameStart, i), kind: kind, scopeEnd: nil))
                    // Only the at-rules whose bodies hold RULES become scopes. A
                    // `@keyframes` holds steps, `@font-face` descriptors and a
                    // `@mixin` its own template — listing their insides is noise.
                    if isAtRule, Self.nestingAtRules.contains(where: { name.hasPrefix($0) }) {
                        listed = rules.count - 1
                    }
                }
                blockStack.append(listed)
                depth += 1
                preludeStart = i + 1
                preludeComments = []
            case 0x7D: // }
                if depth > 0 {
                    depth -= 1
                    if let idx = blockStack.popLast() ?? nil { rules[idx].scopeEnd = i + 1 }
                }
                preludeStart = i + 1
                preludeComments = []
            case 0x3B: // ;
                preludeStart = i + 1
                preludeComments = []
            default:
                break
            }
            i += 1
        }

        // A map with thousands of entries is not a map: past the limit keep the
        // structure (sections, at-rules) and drop the selectors.
        if rules.filter({ $0.kind == .selector }).count > selectorLimit {
            rules.removeAll { $0.kind == .selector }
        }

        var out: [Symbol] = []
        out.reserveCapacity(banners.count + rules.count)
        for (k, b) in banners.enumerated() {
            let end = k + 1 < banners.count ? banners[k + 1].location : n
            out.append(Symbol(name: b.name, kind: .heading,
                              range: NSRange(location: b.location, length: b.length), line: b.line,
                              scopeRange: NSRange(location: b.location, length: max(b.length, end - b.location))))
        }
        for r in rules {
            let scope = r.scopeEnd.map { NSRange(location: r.location, length: $0 - r.location) }
            out.append(Symbol(name: r.name, kind: r.kind, range: NSRange(location: r.location, length: r.length),
                              line: r.line, scopeRange: scope))
        }
        return out.sorted { $0.range.location < $1.range.location }
    }

    /// The prelude's text with the comment ranges inside it removed.
    private static func preludeText(_ raw: NSRange, cutting comments: [NSRange], in ns: NSString) -> String {
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

    /// The section name a comment body yields, or nil when the comment is not a
    /// banner (see the type doc for the rule).
    static func bannerName(_ body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
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
