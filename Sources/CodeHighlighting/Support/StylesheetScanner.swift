//
//  StylesheetScanner.swift
//  CodeHighlighting
//
//  One pass over a stylesheet's UTF-16 units collecting section banners (comments that read as
//  headings) and rules (selectors, at-rules, top-level variables) with their block extents.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// One pass over a stylesheet's UTF-16 units collecting section banners (comments that read
/// as headings) and rules (selectors, at-rules, top-level variables) with their block extents.
/// Strings are skipped whole; nothing inside one opens, closes or ends anything.
struct StylesheetScanner {
    struct Banner { let name: String; let location: Int; let length: Int; let line: Int }
    struct Rule {
        let name: String; let location: Int; let length: Int; let line: Int
        let kind: SymbolKind; var scopeEnd: Int?
    }

    let ns: NSString
    let length: Int
    private let buf: [unichar]
    /// `//` comments count (SCSS / Less), or not (CSS).
    private let lineComments: Bool

    private(set) var banners: [Banner] = []
    private(set) var rules: [Rule] = []

    private var i = 0
    private var line = 1
    private var lineStart = 0
    private var depth = 0
    /// Per open brace: the index in `rules` of the listed at-rule it opened, or nil for a
    /// plain rule's block (whose contents are never listed).
    private var blockStack: [Int?] = []
    /// Where the current prelude began (after the last `;` `{` `}`), and the comment ranges
    /// inside it to cut out of its name.
    private var preludeStart = 0
    private var preludeComments: [NSRange] = []

    init(_ ns: NSString, lineComments: Bool) {
        self.ns = ns; length = ns.length; self.lineComments = lineComments
        var buf = [unichar](repeating: 0, count: ns.length)
        if ns.length > 0 { ns.getCharacters(&buf, range: NSRange(location: 0, length: ns.length)) }
        self.buf = buf
    }

    mutating func scan() {
        while i < length {
            let c = buf[i]
            if c == 0x0A { line += 1; i += 1; lineStart = i; continue }
            if c == 0x2F, i + 1 < length, buf[i + 1] == 0x2A { scanBlockComment(); continue }
            if lineComments, c == 0x2F, i + 1 < length, buf[i + 1] == 0x2F, !(i > 0 && buf[i - 1] == 0x3A) {   // not the `//` in url(http://…)
                scanLineComments(); continue
            }
            if c == 0x22 || c == 0x27 { skipString(quote: c); continue }
            switch c {
            case 0x7B: openBlock()
            case 0x7D: closeBlock()
            case 0x3B: endStatement()
            default: break
            }
            i += 1
        }
    }

    // MARK: - Comments and strings

    /// A `/* … */` — a section candidate when it starts its own top-level line.
    private mutating func scanBlockComment() {
        let start = i, startLine = line
        var j = i + 2
        var lastNewline: Int? = nil
        while j + 1 < length, !(buf[j] == 0x2A && buf[j + 1] == 0x2F) {
            if buf[j] == 0x0A { line += 1; lastNewline = j }
            j += 1
        }
        let end = j + 1 < length ? j + 2 : length
        if depth == 0, isBlank(lineStart, start),
           let name = StylesheetOutline.bannerName(ns.substring(with: NSRange(location: start + 2, length: max(0, j - start - 2)))) {
            banners.append(Banner(name: name, location: start, length: end - start, line: startLine))
        }
        preludeComments.append(NSRange(location: start, length: end - start))
        if let lastNewline { lineStart = lastNewline + 1 }
        i = end
    }

    /// A `//` comment. On its own top-level line it may head a block of consecutive `//` rows:
    /// SCSS banners are `// ----` / `// Title` / `// ----`, and a lone `// Label` directly above
    /// code is a label; prose paragraphs are neither.
    private mutating func scanLineComments() {
        guard depth == 0, isBlank(lineStart, i) else {
            let start = i
            while i < length, buf[i] != 0x0A { i += 1 }
            preludeComments.append(NSRange(location: start, length: i - start))
            return
        }
        var rows: [(text: String, location: Int, line: Int)] = []
        var k = i
        while true {
            var e = k
            while e < length, buf[e] != 0x0A { e += 1 }
            rows.append((ns.substring(with: NSRange(location: k + 2, length: e - k - 2)), k, line))
            preludeComments.append(NSRange(location: k, length: e - k))
            i = e   // the newline (or EOF) is the main loop's
            guard e < length else { break }
            var p = e + 1
            while p < length, buf[p] == 0x20 || buf[p] == 0x09 || buf[p] == 0x0D { p += 1 }
            guard p + 1 < length, buf[p] == 0x2F, buf[p + 1] == 0x2F, !(buf[p - 1] == 0x3A) else { break }
            line += 1
            lineStart = e + 1
            k = p
        }
        var q = i
        while q < length, Self.isWS(buf[q]) { q += 1 }
        let nextIsCode = q < length && buf[q] != 0x2F
        for b in StylesheetOutline.lineCommentBanners(rows, nextIsCode: nextIsCode) {
            banners.append(Banner(name: b.name, location: b.location, length: b.length, line: b.line))
        }
    }

    private mutating func skipString(quote: unichar) {
        var j = i + 1
        while j < length, buf[j] != quote {
            if buf[j] == 0x5C { j += 1 }                     // escaped char
            if j < length, buf[j] == 0x0A { line += 1; lineStart = j + 1 }
            j += 1
        }
        i = min(length, j + 1)
    }

    // MARK: - Structure

    /// `{`: the prelude before it names a rule. Only at-rules whose bodies hold RULES become
    /// scopes — a `@keyframes` holds steps, `@font-face` descriptors, a `@mixin` its template.
    private mutating func openBlock() {
        let name = preludeName()
        var listed: Int? = nil
        if !name.isEmpty, depth == 0 || blockStack.last! != nil {
            let nameStart = preludeNameStart()
            let isAtRule = name.hasPrefix("@")
            let kind: SymbolKind = isAtRule
                ? (name.hasPrefix("@mixin") || name.hasPrefix("@function") ? .function : .module)
                : .selector
            rules.append(Rule(name: name, location: nameStart, length: max(1, i - nameStart),
                              line: line - newlines(nameStart, i), kind: kind, scopeEnd: nil))
            if isAtRule, StylesheetOutline.nestingAtRules.contains(where: { name.hasPrefix($0) }) { listed = rules.count - 1 }
        }
        blockStack.append(listed)
        depth += 1
        startPrelude(after: i)
    }

    private mutating func closeBlock() {
        if depth > 0 {
            depth -= 1
            if let idx = blockStack.popLast() ?? nil { rules[idx].scopeEnd = i + 1 }
        }
        startPrelude(after: i)
    }

    /// `;`: a top-level `$name: value;` (SCSS) or `@name: value;` (Less) is a variable — the
    /// whole content of a tokens partial. Inside a block it is a local and stays out.
    private mutating func endStatement() {
        if depth == 0, let name = StylesheetOutline.variableName(in: preludeName()) {
            let nameStart = preludeNameStart()
            rules.append(Rule(name: name, location: nameStart, length: (name as NSString).length,
                              line: line - newlines(nameStart, i), kind: .variable, scopeEnd: nil))
        }
        startPrelude(after: i)
    }

    private mutating func startPrelude(after index: Int) {
        preludeStart = index + 1
        preludeComments = []
    }

    // MARK: - Prelude helpers

    /// The current prelude's text, comments cut out, whitespace collapsed.
    private func preludeName() -> String {
        let raw = NSRange(location: preludeStart, length: i - preludeStart)
        return Self.collapsed(StylesheetOutline.preludeText(raw, cutting: preludeComments, in: ns))
    }

    /// The first offset in the prelude that is neither whitespace nor inside a comment.
    private func preludeNameStart() -> Int {
        var nameStart = preludeStart
        while nameStart < i, Self.isWS(buf[nameStart]) || preludeComments.contains(where: { NSLocationInRange(nameStart, $0) }) { nameStart += 1 }
        return nameStart
    }

    private func isBlank(_ from: Int, _ to: Int) -> Bool {
        var k = from
        while k < to { if !Self.isWS(buf[k]) { return false }; k += 1 }
        return true
    }

    private func newlines(_ from: Int, _ to: Int) -> Int {
        var count = 0, k = from
        while k < to { if buf[k] == 0x0A { count += 1 }; k += 1 }
        return count
    }

    static func isWS(_ c: unichar) -> Bool { c == 0x20 || c == 0x09 || c == 0x0D || c == 0x0A }

    static func collapsed(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }
}
