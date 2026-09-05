//
//  XMLRules.swift
//  CodeHighlighting
//
//  The regex rule table for XML.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table for XML. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let xml: [(String, TokenKind)] = [
        htmlComment,
        doubleQuotedPlain,
        singleQuotedPlain,
        ("</?[a-zA-Z][\\w:._-]*", .keyword),
        ("/>|>", .keyword),
    ]
}
