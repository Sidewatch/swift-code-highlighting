//
//  JSONRules.swift
//  CodeHighlighting
//
//  The regex rule table for JSON.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for JSON. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let json: [(String, TokenKind)] = [
        ("\"(?:[^\"\\\\]|\\\\.)*\"\\s*:", .function),
        doubleQuoted,
        keywords(["true", "false", "null"]),
        ("\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", .number),
    ]
}
