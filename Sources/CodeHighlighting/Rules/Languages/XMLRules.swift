//
//  XMLRules.swift
//  CodeHighlighting
//
//  The regex rule table for XML.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for XML. Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let xml: [(String, TokenKind)] = [
        htmlComment,
        doubleQuotedPlain,
        singleQuotedPlain,
        ("</?[a-zA-Z][\\w:._-]*", .keyword),
        ("/>|>", .keyword),
    ]
}
