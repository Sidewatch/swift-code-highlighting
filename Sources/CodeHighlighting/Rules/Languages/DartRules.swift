import Foundation

/// The regex rule table for Dart. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let dart: [(String, TokenKind)] = [
        ("///.*$", .comment),
        lineComment,
        blockComment,
        doubleQuoted,
        singleQuoted,
        keywords([
            "abstract", "class", "const", "final", "var", "void", "dynamic", "import", "export", "library",
            "part", "return", "if", "else", "for", "while", "do", "switch", "case", "default",
            "break", "continue", "new", "this", "super", "async", "await", "yield", "try", "catch",
            "finally", "throw", "extends", "implements", "with", "mixin", "enum", "typedef", "get", "set",
            "factory", "static", "late", "required", "is", "as", "in", "rethrow", "on", "show",
            "hide",
        ]),
        types([
            "int", "double", "num", "bool", "String", "List", "Map", "Set", "Future", "Stream",
            "Object", "void", "var", "Widget", "BuildContext",
        ]),
        constants(["true", "false", "null"]),
        decimal,
        call,
        ("@\\w+", .attribute),
    ]
}
