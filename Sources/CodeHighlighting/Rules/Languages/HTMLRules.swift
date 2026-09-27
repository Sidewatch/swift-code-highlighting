//
//  HTMLRules.swift
//  CodeHighlighting
//
//  The regex rule table for HTML.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for HTML.
/// Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let html: [(String, TokenKind)] = [
        htmlComment,
        doubleQuotedPlain,
        singleQuotedPlain,
        ("</?[a-zA-Z][\\w-]*", .keyword),
        ("/>|>", .keyword),
        ("\\b[a-zA-Z-]+=", .function),
    ]
}
