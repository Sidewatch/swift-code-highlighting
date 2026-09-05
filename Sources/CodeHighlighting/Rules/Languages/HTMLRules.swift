//
//  HTMLRules.swift
//  CodeHighlighting
//
//  The regex rule table for HTML.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table for HTML. Order matters: earlier rules win overlaps.
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
