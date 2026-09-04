import Foundation

/// The regex rule table for TOML. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let toml: [(String, TokenKind)] = [
        hashComment,
        tripleDoubleQuoted,
        doubleQuoted,
        singleQuotedPlain,
        ("^\\s*\\[{1,2}[^\\]]*\\]{1,2}", .keyword),
        ("^\\s*[a-zA-Z_][\\w.-]*\\s*=", .function),
        constants(["true", "false"]),
        decimal,
    ]
}
