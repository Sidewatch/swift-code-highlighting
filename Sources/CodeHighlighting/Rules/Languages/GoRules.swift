import Foundation

/// The regex rule table for Go. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let go: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        ("`[^`]*`", .string),
        doubleQuoted,
        keywords([
                "package", "import", "func", "return", "var", "const", "type", "struct", "interface", "map",
                "chan", "go", "defer", "if", "else", "for", "range", "switch", "case", "default",
                "break", "continue", "fallthrough", "select", "nil",
            ]),
        constants(["true", "false", "iota"]),
        types([
                "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16", "uint32", "uint64",
                "float32", "float64", "byte", "rune", "string", "bool", "error", "any",
            ]),
        decimal,
        call,
    ]
}
