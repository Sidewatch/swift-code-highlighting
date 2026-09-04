import Foundation

/// The regex rule table for PHP. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let php: [(String, TokenKind)] = [
        lineComment,
        hashComment,
        blockComment,
        doubleQuoted,
        singleQuoted,
        ("<\\?php|\\?>", .keyword),
        keywords([
            "function", "class", "interface", "trait", "extends", "implements", "public", "private", "protected", "static",
            "const", "return", "if", "else", "elseif", "foreach", "for", "while", "do", "switch",
            "case", "break", "continue", "echo", "print", "new", "use", "namespace", "require", "require_once",
            "include", "include_once", "try", "catch", "finally", "throw", "as", "instanceof", "abstract", "final",
            "global", "isset", "unset", "empty", "array", "fn", "match", "yield",
        ]),
        constants(["true", "false", "null"]),
        ("\\$[a-zA-Z_]\\w*", .type),
        decimal,
        call,
    ]
}
