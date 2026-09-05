//
//  JavaScriptRules.swift
//  CodeHighlighting
//
//  The regex rule table for JavaScript / Typescript.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table for JavaScript / Typescript. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let javascript: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        backQuoted,
        doubleQuoted,
        singleQuoted,
        keywords([
            "import", "export", "from", "default", "const", "let", "var", "function", "return", "if",
            "else", "for", "while", "do", "break", "continue", "switch", "case", "throw", "try",
            "catch", "finally", "new", "delete", "typeof", "instanceof", "in", "of", "class", "extends",
            "super", "this", "yield", "async", "await", "static", "get", "set", "interface", "type",
            "enum", "implements", "readonly", "public", "private", "protected", "namespace", "declare", "as", "satisfies",
            "keyof",
        ]),
        constants(["true", "false", "null", "undefined", "NaN", "Infinity"]),
        types([
            "Array", "Object", "String", "Number", "Boolean", "Function", "Promise", "Map", "Set", "RegExp",
            "Date", "Error", "JSON", "Math", "console",
        ]),
        decimalOrHex,
        ("\\b([a-zA-Z_$][\\w$]*)\\s*\\(", .function),
        ("=>", .keyword),
    ]
}
