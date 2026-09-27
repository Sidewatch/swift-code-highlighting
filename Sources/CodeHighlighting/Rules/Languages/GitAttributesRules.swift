//
//  GitAttributesRules.swift
//  CodeHighlighting
//
//  The regex rule table for .gitattributes.
//
//  Created by David Sherlock on 9/25/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// `.gitattributes`: `#` comments, the path pattern first on the line, `attr=value` settings,
/// the attribute names git knows, `-attr` / `!attr` unset.
extension RuleTables {
    static let gitattributes: [(String, TokenKind)] = [
        hashComment,
        ("^\\S+", .function),
        ("[-!][\\w.-]+", .removed),
        ("\\b(text|binary|diff|merge|filter|eol|export-ignore|export-subst|delta|encoding|ident|whitespace|working-tree-encoding|linguist-[\\w-]+|gitlab-[\\w-]+|conflict-marker-size)\\b", .keyword),
        ("=[\\w.-]+", .property),
    ]
}
