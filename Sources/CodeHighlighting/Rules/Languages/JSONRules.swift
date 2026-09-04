import Foundation

/// The regex rule table for JSON. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let json: [(String, TokenKind)] = [
        ("\"(?:[^\"\\\\]|\\\\.)*\"\\s*:", .function),
        doubleQuoted,
        keywords(["true", "false", "null"]),
        ("\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", .number),
    ]
}
