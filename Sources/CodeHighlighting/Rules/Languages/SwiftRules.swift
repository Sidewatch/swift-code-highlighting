import Foundation

/// The regex rule table for Swift. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let swift: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        doubleQuoted,
        keywords([
                "import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let", "if",
                "else", "guard", "switch", "case", "default", "for", "while", "repeat", "return", "break",
                "continue", "throw", "throws", "try", "catch", "do", "in", "as", "is", "self",
                "Self", "super", "init", "deinit", "static", "override", "private", "public", "internal", "fileprivate",
                "open", "final", "lazy", "weak", "unowned", "mutating", "async", "await", "actor", "some",
                "any", "where", "typealias", "defer", "indirect",
            ]),
        types([
                "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Optional", "Result",
                "Error", "Void", "Any", "AnyObject", "Never", "Data", "Date", "URL", "UUID",
            ]),
        constants(["true", "false", "nil"]),
        decimalOrHex,
        call,
        ("@\\w+", .attribute),
    ]
}
