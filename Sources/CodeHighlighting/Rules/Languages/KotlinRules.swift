//
//  KotlinRules.swift
//  CodeHighlighting
//
//  The regex rule table for Kotlin.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for Kotlin.
/// Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let kotlin: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        tripleDoubleQuoted,
        doubleQuoted,
        singleQuoted,
        keywords([
            "fun", "val", "var", "class", "object", "interface", "data", "sealed", "enum", "import",
            "package", "return", "if", "else", "when", "for", "while", "do", "in", "is",
            "as", "null", "this", "super", "override", "open", "abstract", "private", "public", "internal",
            "protected", "companion", "init", "constructor", "by", "lateinit", "suspend", "typealias", "vararg", "inline",
            "reified", "operator", "infix", "out",
        ]),
        constants(["true", "false", "null"]),
        types([
            "Int", "Long", "Double", "Float", "Boolean", "String", "Char", "Byte", "Short", "Unit",
            "Any", "Nothing", "List", "Map", "Set", "Array", "MutableList", "MutableMap", "Pair",
        ]),
        ("\\b\\d+(\\.\\d+)?[fFlLdD]?\\b", .number),
        call,
        ("@\\w+", .attribute),
    ]
}
