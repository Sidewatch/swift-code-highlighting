//
//  ErlangRules.swift
//  CodeHighlighting
//
//  The regex rule table for Erlang.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Erlang: `%` comments, quoted atoms, capitalised variables, `-module(...)` attributes,
/// `?MACRO`, `#record`, `Mod:fun(` calls. Written 25 Sep 2026 when a sweep of every sample found
/// the language painted nothing (it fell to the empty plain family).
extension RuleTables {
    static let erlang: [(String, TokenKind)] = [
        ("%.*$", .comment),
        doubleQuoted,
        ("'(?:[^'\\\\]|\\\\.)*'", .string),
        ("^-[a-z_]+", .attribute),
        keywords(["module", "export", "import", "define", "record", "behaviour", "behavior", "include", "include_lib", "spec", "type", "opaque", "callback",
                  "fun", "case", "of", "end", "if", "when", "receive", "after", "try", "catch", "throw", "begin", "and", "or", "not", "andalso", "orelse",
                  "div", "rem", "bnot", "band", "bor", "bxor", "bsl", "bsr", "xor", "cond", "let", "query"]),
        ("\\?[A-Z_][A-Za-z0-9_]*", .type),
        ("#[a-z_]\\w*", .type),
        ("\\b[A-Z_][A-Za-z0-9_@]*\\b", .variable),
        ("\\b[a-z]\\w*:[a-z]\\w*(?=\\()", .function),
        ("\\b[a-z]\\w*(?=\\()", .function),
        ("\\b\\d+#[0-9a-zA-Z]+\\b|\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b|\\$.", .number),
    ]
}
