//
//  TexinfoRules.swift
//  CodeHighlighting
//
//  The regex rule table for Texinfo.
//
//  Created by David Sherlock on 9/25/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Texinfo: `@c` comments, `@commands`, `@node` lines, braced arguments, `@@` escapes,
/// the `@example` bodies left alone.
extension RuleTables {
    static let texinfo: [(String, TokenKind)] = [
        ("^@(c|comment)\\b.*$", .comment),
        ("^@node\\s.*$", .function),
        ("^@(chapter|section|subsection|subsubsection|top|unnumbered|appendix|heading|majorheading|title|subtitle|author|settitle|setfilename)\\b.*$", .type),
        ("@[a-zA-Z]+", .keyword),
        ("@[@{}]", .keyword),
        ("(?<=@[a-zA-Z]{1,20})\\{[^}]*\\}", .string),
        ("\\b\\d+(\\.\\d+)?\\b", .number),
    ]
}
