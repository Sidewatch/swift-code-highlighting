//
//  CSSRules.swift
//  CodeHighlighting
//
//  The regex rule table for CSS.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for CSS. Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let css: [(String, TokenKind)] = [
        blockComment,
        doubleQuoted,
        singleQuoted,
        ("#[0-9a-fA-F]{3,8}\\b", .number),
        ("\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|s|ms|fr|deg)?\\b", .number),
        ("[.#][a-zA-Z_-][\\w-]*", .function),
        ("@(media|import|keyframes|font-face|supports|include|mixin|use|forward)\\b", .keyword),
        ("[a-z-]+(?=\\s*:)", .type),
    ]
}
