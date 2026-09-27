//
//  StringsRules.swift
//  CodeHighlighting
//
//  The regex rule table for Xcode .strings.
//
//  Created by David Sherlock on 9/25/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// `.strings`: `/* */` and `//` comments, the key before `=` (quoted or bare), the quoted
/// value, the `=` and `;` between them. Format specifiers sit inside strings, which the regex
/// tier paints last and whole, so they cannot show.
extension RuleTables {
    static let strings: [(String, TokenKind)] = [
        blockComment,
        lineComment,
        ("\"(?:[^\"\\\\]|\\\\.)*\"(?=\\s*=)", .property),
        doubleQuoted,
        ("\\b[A-Za-z_][\\w.]*(?=\\s*=)", .property),
        ("[=;]", .keyword),
    ]
}
