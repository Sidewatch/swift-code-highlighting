//
//  AstroRules.swift
//  CodeHighlighting
//
//  The regex rule table for Astro.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table for Astro. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let astro: [(String, TokenKind)] = [
        htmlComment,
        lineComment,
        blockComment,
        backQuoted,
        doubleQuoted,
        singleQuoted,
        ("^---\\s*$", .keyword),
        ("</?[A-Z][\\w.]*", .type),
        ("</?[a-z][\\w-]*", .keyword),
        ("/>|>", .keyword),
        keywords([
            "import", "export", "from", "const", "let", "var", "function", "return", "if", "else",
            "for", "while", "await", "async", "new", "class", "interface", "type", "typeof", "extends",
            "of", "in",
        ]),
        decimal,
        ("\\b[a-zA-Z_:][\\w:-]*=", .function),
    ]
}
