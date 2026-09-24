//
//  PrologRules.swift
//  CodeHighlighting
//
//  The regex rule table for Prolog.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Prolog: `%` and block comments, quoted atoms, capitalised variables, the `:-` neck, predicate
/// calls. Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let prolog: [(String, TokenKind)] = [
        ("%.*$", .comment),
        blockComment,
        doubleQuoted,
        ("'(?:[^'\\\\]|\\\\.)*'", .string),
        (":-|-->|\\?-|\\\\\\+|->|;", .keyword),
        keywords(["is", "mod", "rem", "not", "true", "fail", "false", "dynamic", "discontiguous", "module", "use_module", "initialization", "findall", "bagof", "setof", "forall", "length", "member", "append", "nth0", "nth1", "assert", "asserta", "assertz", "retract", "write", "writeln", "nl", "format", "halt"]),
        ("\\b[A-Z_][A-Za-z0-9_]*\\b", .variable),
        ("\\b[a-z]\\w*(?=\\()", .function),
        ("\\b\\d+(\\.\\d+)?\\b", .number),
    ]
}
