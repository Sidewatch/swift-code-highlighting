//
//  StringsRules.swift
//  CodeHighlighting
//
//  The regex rule table for Xcode .strings.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// `.strings`: `/* */` and `//` comments, the key before `=` (quoted or bare), the quoted
/// value, the `=` and `;` between them (format specifiers sit inside strings, which the regex
/// tier paints last and whole, so they cannot show). Written 25 Sep 2026 (the sweep found two roles).
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
