//
//  AsciiDocRules.swift
//  CodeHighlighting
//
//  The regex rule table for AsciiDoc.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// AsciiDoc: `=` headings, `//` comments, block titles, `[attribute]` lines, `:name:` entries,
/// block delimiters, inline bold / italic / mono, `<<xrefs>>`, admonitions, tables, list
/// markers. Written 25 Sep 2026 (the sweep found one role).
extension RuleTables {
    static let asciidoc: [(String, TokenKind)] = [
        ("^//.*$", .comment),
        ("^(----|====|\\*\\*\\*\\*|\\+\\+\\+\\+|____|\\.\\.\\.\\.|\\|===)\\s*$", .comment),
        ("^=+\\s.*$", .keyword),
        ("^\\.[A-Za-z].*$", .type),
        ("^\\[[^\\]]*\\]\\s*$", .attribute),
        ("^:[\\w-]+!?:", .property),
        ("^\\s*[*.-]+\\s", .keyword),
        ("^\\s*\\d+\\.\\s", .keyword),
        ("\\b(NOTE|TIP|IMPORTANT|WARNING|CAUTION):", .removed),
        ("<<[^>]+>>", .function),
        ("\\b(https?|link|xref|image|include|mailto):[^\\s\\[]+(\\[[^\\]]*\\])?", .string),
        ("`[^`]+`", .string),
        ("\\*[^*\\n]+\\*", .type),
        ("_[^_\\n]+_", .variable),
        ("^\\|", .comment),
    ]
}
