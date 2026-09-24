//
//  BibTeXRules.swift
//  CodeHighlighting
//
//  The regex rule table for BibTeX.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// BibTeX: `%` comments, `@entry{` types, `key = ` fields, `{…}` and `"…"` values, numbers.
/// Written 25 Sep 2026 (the corpus sweep found two roles).
extension RuleTables {
    static let bibtex: [(String, TokenKind)] = [
        ("%.*$", .comment),
        ("@[A-Za-z]+(?=\\s*[{(])", .keyword),
        ("^\\s*[A-Za-z_-]+(?=\\s*=)", .property),
        ("(?<==)\\s*\\{[\\s\\S]*?\\}(?=\\s*[,}\\n])", .string),
        doubleQuoted,
        ("(?<=[{(])\\s*[\\w:.-]+(?=\\s*,)", .type),
        ("\\b\\d+(--\\d+)?\\b", .number),
    ]
}
