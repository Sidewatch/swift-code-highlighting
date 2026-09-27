//
//  RubyRules.swift
//  CodeHighlighting
//
//  The regex rule table for Ruby.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for Ruby.
/// Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let ruby: [(String, TokenKind)] = [
        hashComment,
        doubleQuoted,
        singleQuoted,
        keywords([
            "alias", "and", "begin", "break", "case", "class", "def", "do", "else", "elsif",
            "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not",
            "or", "redo", "rescue", "retry", "return", "self", "super", "then", "true", "undef",
            "unless", "until", "when", "while", "yield", "require", "include",
        ]),
        (":[a-zA-Z_]\\w*", .string),
        decimal,
        ("@{1,2}[a-zA-Z_]\\w*", .type),
    ]
}
