//
//  QuerySourceScanner.swift
//  CodeHighlighting
//
//  A shallow, safe reader of tree-sitter query source: one top-level form at a time — `(...)`,
//  `[...]` or `"literal"` with its trailing quantifiers and `@capture` chains — `;` comments
//  kept, anything unrecognised copied verbatim (unknown syntax can only be kept, never
//  dropped).
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// A shallow, safe reader of tree-sitter query source: one top-level form at a time —
/// `(...)`, `[...]` or `"literal"` with its trailing quantifiers and `@capture` chains —
/// `;` comments kept, anything unrecognised copied verbatim (unknown syntax can only be
/// kept, never dropped).
struct QuerySourceScanner {
    private let s: [Unicode.Scalar]
    private var i = 0

    init(_ source: String) { s = Array(source.unicodeScalars) }

    enum Token { case whitespace(Unicode.Scalar), comment(String), pattern(String), bare(String) }

    /// One top-level token: whitespace, a comment line, a pattern with its suffixes, or a bare
    /// token. Nil at the end.
    mutating func next() -> Token? {
        guard i < s.count else { return nil }
        let c = s[i]
        if Self.isWS(c) { i += 1; return .whitespace(c) }
        if c == ";" { return .comment(take { $0 != "\n" }) }
        if c == "(" || c == "[" || c == "\"" {
            let start = i
            consumeForm()
            consumeSuffixes()
            return .pattern(String(String.UnicodeScalarView(s[start..<i])))
        }
        return .bare(take { !Self.isWS($0) })
    }

    static func isWS(_ c: Unicode.Scalar) -> Bool { c == " " || c == "\n" || c == "\t" || c == "\r" }

    private mutating func take(while keep: (Unicode.Scalar) -> Bool) -> String {
        let start = i
        while i < s.count, keep(s[i]) { i += 1 }
        return String(String.UnicodeScalarView(s[start..<i]))
    }

    /// Past one balanced form starting at `i`: a quoted string, or a paren/bracket group
    /// honouring nested strings and comments.
    private mutating func consumeForm() {
        if s[i] == "\"" { i += 1; skipString(); return }
        var depth = 0
        while i < s.count {
            switch s[i] {
            case "\"": i += 1; skipString(); continue
            case "(", "[": depth += 1
            case ")", "]":
                depth -= 1
                if depth == 0 { i += 1; return }
            case ";": while i < s.count, s[i] != "\n" { i += 1 }
            default: break
            }
            i += 1
        }
    }

    /// Past the closing quote of a string whose opening quote is already consumed.
    private mutating func skipString() {
        while i < s.count {
            if s[i] == "\\" { i += 2; continue }
            if s[i] == "\"" { i += 1; return }
            i += 1
        }
    }

    /// Trailing quantifiers (`? * +`) and `@capture` chains belong to the pattern before them.
    private mutating func consumeSuffixes() {
        while i < s.count {
            var k = i
            while k < s.count, Self.isWS(s[k]) { k += 1 }
            if k < s.count, s[k] == "?" || s[k] == "*" || s[k] == "+" {
                i = k + 1
            } else if k < s.count, s[k] == "@" {
                k += 1
                while k < s.count, !Self.isWS(s[k]), !"()[];".unicodeScalars.contains(s[k]) { k += 1 }
                i = k
            } else { return }
        }
    }
}
