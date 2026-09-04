import Foundation

/// The regex rule table for Python. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let python: [(String, TokenKind)] = [
        tripleDoubleQuoted,
        tripleSingleQuoted,
        hashComment,
        doubleQuoted,
        singleQuoted,
        keywords([
            "import", "from", "class", "def", "return", "if", "elif", "else", "for", "while",
            "break", "continue", "pass", "raise", "try", "except", "finally", "with", "as", "yield",
            "lambda", "global", "nonlocal", "assert", "del", "in", "not", "and", "or", "is",
            "async", "await", "match", "case",
        ]),
        constants(["True", "False", "None"]),
        types([
            "int", "float", "str", "bool", "list", "dict", "set", "tuple", "range", "print",
            "len", "super", "type", "object",
        ]),
        decimal,
        call,
        ("@\\w[\\w.]*", .attribute),
    ]
}
