//
//  JavaRules.swift
//  CodeHighlighting
//
//  The regex rule table for Java.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table for Java. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let java: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        doubleQuoted,
        keywords([
            "abstract", "break", "case", "catch", "class", "continue", "default", "do", "else", "enum",
            "extends", "final", "finally", "for", "if", "implements", "import", "instanceof", "interface", "new",
            "package", "private", "protected", "public", "return", "static", "super", "switch", "this", "throw",
            "throws", "try", "volatile", "while", "var", "yield",
        ]),
        constants(["true", "false", "null"]),
        types([
            "boolean", "byte", "char", "double", "float", "int", "long", "short", "void", "String",
            "Integer", "Long", "Double", "Object", "List", "Map", "Set", "Optional",
        ]),
        decimal,
        call,
        ("@[a-zA-Z_]\\w*", .attribute),
    ]
}
