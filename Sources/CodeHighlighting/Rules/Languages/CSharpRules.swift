import Foundation

/// The regex rule table for CSharp. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let csharp: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        ("@?\"(?:[^\"\\\\]|\\\\.)*\"", .string),
        singleQuoted,
        keywords([
            "using", "namespace", "class", "struct", "interface", "enum", "public", "private", "protected", "internal",
            "static", "readonly", "const", "void", "new", "return", "if", "else", "for", "foreach",
            "while", "do", "switch", "case", "default", "break", "continue", "throw", "try", "catch",
            "finally", "async", "await", "get", "set", "this", "base", "override", "virtual", "abstract",
            "sealed", "partial", "in", "out", "ref", "params", "is", "as", "typeof", "nameof",
            "record", "when", "where", "yield", "lock", "using",
        ]),
        types([
            "int", "long", "short", "byte", "bool", "char", "string", "double", "float", "decimal",
            "object", "dynamic", "var", "List", "Dictionary", "IEnumerable", "Task", "Nullable",
        ]),
        constants(["true", "false", "null"]),
        ("\\b\\d+(\\.\\d+)?[fFdDmMlL]?\\b", .number),
        call,
        ("\\[[A-Za-z]\\w*(\\([^)]*\\))?\\]", .attribute),
    ]
}
