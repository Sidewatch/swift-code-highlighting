//
//  RuleTables+Builders.swift
//  CodeHighlighting
//
//  The rules every table is built from.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The rules every table is built from. A table is an array of (pattern, kind): the named
/// constants cover the idioms most languages share, the word-list builders turn a list of
/// words into one `\b(a|b|c)\b` alternation of the given kind.
extension RuleTables {

    // MARK: Comments

    /// `// …` to the end of the line.
    static let lineComment: (String, TokenKind) = ("//.*$", .comment)
    /// `/* … */`, across lines.
    static let blockComment: (String, TokenKind) = ("/\\*[\\s\\S]*?\\*/", .comment)
    /// `# …` to the end of the line.
    static let hashComment: (String, TokenKind) = ("#.*$", .comment)
    /// `-- …` to the end of the line.
    static let dashComment: (String, TokenKind) = ("--.*$", .comment)
    /// `<!-- … -->`, across lines.
    static let htmlComment: (String, TokenKind) = ("<!--[\\s\\S]*?-->", .comment)

    // MARK: Strings

    /// `"…"` with backslash escapes.
    static let doubleQuoted: (String, TokenKind) = ("\"(?:[^\"\\\\]|\\\\.)*\"", .string)
    /// `'…'` with backslash escapes.
    static let singleQuoted: (String, TokenKind) = ("'(?:[^'\\\\]|\\\\.)*'", .string)
    /// `` `…` `` with backslash escapes.
    static let backQuoted: (String, TokenKind) = ("`(?:[^`\\\\]|\\\\.)*`", .string)
    /// `"…"` with no escapes (data formats).
    static let doubleQuotedPlain: (String, TokenKind) = ("\"[^\"]*\"", .string)
    /// `'…'` with no escapes.
    static let singleQuotedPlain: (String, TokenKind) = ("'[^']*'", .string)
    /// `"""…"""`, across lines, no escapes.
    static let tripleDoubleQuoted: (String, TokenKind) = ("\"\"\"[\\s\\S]*?\"\"\"", .string)
    /// `'''…'''`, across lines, no escapes.
    static let tripleSingleQuoted: (String, TokenKind) = ("'''[\\s\\S]*?'''", .string)

    // MARK: Numbers and calls

    /// Integers and decimals.
    static let decimal: (String, TokenKind) = ("\\b\\d+(\\.\\d+)?\\b", .number)
    /// Integers, decimals and `0x` hex literals.
    static let decimalOrHex: (String, TokenKind) = ("\\b\\d+(\\.\\d+)?\\b|\\b0x[0-9a-fA-F]+\\b", .number)
    /// An identifier followed by `(`: the callee is captured as group 1.
    static let call: (String, TokenKind) = ("\\b([a-zA-Z_]\\w*)\\s*\\(", .function)

    // MARK: Word lists

    /// The words as keywords.
    static func keywords(_ words: [String]) -> (String, TokenKind) { alternation(words, .keyword) }
    /// The words as type names.
    static func types(_ words: [String]) -> (String, TokenKind) { alternation(words, .type) }
    /// Literal constants (`true`, `nil`, …) are painted as numbers.
    static func constants(_ words: [String]) -> (String, TokenKind) { alternation(words, .number) }
    /// The words as function names, whether or not a `(` follows.
    static func functions(_ words: [String]) -> (String, TokenKind) { alternation(words, .function) }

    /// `\b(a|b|c)\b` of `kind`. Words are used verbatim, so they must be regex-safe.
    static func alternation(_ words: [String], _ kind: TokenKind) -> (String, TokenKind) {
        ("\\b(" + words.joined(separator: "|") + ")\\b", kind)
    }
}
