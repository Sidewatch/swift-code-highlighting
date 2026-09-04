import Foundation

/// The regex rule table shared by every language of the CLike family that has no table of its own.
extension RuleTables {
    static let cLikeFamily: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        doubleQuoted,
        singleQuoted,
        keywords([
                "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
                "return", "struct", "enum", "union", "class", "interface", "trait", "impl", "public", "private",
                "protected", "internal", "static", "final", "const", "let", "var", "val", "func", "fn",
                "def", "void", "new", "delete", "try", "catch", "finally", "throw", "throws", "import",
                "export", "package", "namespace", "using", "module", "use", "extends", "implements", "override", "virtual",
                "abstract", "async", "await", "yield", "match", "when", "where", "type", "typedef", "template",
                "typename", "operator", "this", "self", "super",
            ]),
        constants(["true", "false", "null", "nil", "none", "undefined"]),
        decimalOrHex,
        ("\\b([A-Za-z_]\\w*)\\s*\\(", .function),
    ]
}
