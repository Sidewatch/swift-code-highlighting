import Foundation

/// The regex rule table for C / Cpp. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let c: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        doubleQuoted,
        singleQuoted,
        ("#\\s*(include|define|ifdef|ifndef|endif|if|else|elif|pragma)\\b.*$", .attribute),
        keywords([
                "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else",
                "enum", "extern", "float", "for", "goto", "if", "int", "long", "register", "return",
                "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void",
                "volatile", "while", "inline", "class", "namespace", "template", "typename", "virtual", "public", "private",
                "protected", "override", "new", "delete", "this", "try", "catch", "throw", "using", "nullptr",
                "constexpr", "noexcept",
            ]),
        constants(["true", "false", "NULL", "nullptr"]),
        types([
                "size_t", "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "bool",
                "string", "vector", "map", "set",
            ]),
        decimalOrHex,
        call,
    ]
}
