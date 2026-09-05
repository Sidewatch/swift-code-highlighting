//
//  DataFamilyRules.swift
//  CodeHighlighting
//
//  The regex rule table shared by every language of the Data family that has no table of its
//  own.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table shared by every language of the Data family that has no table of its own.
extension RuleTables {
    static let dataFamily: [(String, TokenKind)] = [
        ("\"(?:[^\"\\\\]|\\\\.)*\"\\s*:", .function),
        doubleQuoted,
        keywords(["true", "false", "null"]),
        ("\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", .number),
    ]
}
