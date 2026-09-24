//
//  JSON5Rules.swift
//  CodeHighlighting
//
//  The regex rule table for JSON5 and Hjson.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// JSON5 and Hjson: JSON plus comments, single-quoted and multi-line strings, unquoted keys,
/// hex and signed numbers, `Infinity` / `NaN`. Written 25 Sep 2026 (the data family gave them
/// no strings).
extension RuleTables {
    static let json5: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        hashComment,
        ("\"(?:[^\"\\\\]|\\\\.)*\"(?=\\s*:)", .function),
        ("'(?:[^'\\\\]|\\\\.)*'(?=\\s*:)", .function),
        ("[A-Za-z_$][\\w$]*(?=\\s*:)", .function),
        tripleSingleQuoted,
        doubleQuoted,
        singleQuoted,
        keywords(["true", "false", "null", "Infinity", "NaN"]),
        ("[+-]?(0[xX][0-9a-fA-F]+|\\d*\\.?\\d+([eE][+-]?\\d+)?)\\b", .number),
    ]
}
