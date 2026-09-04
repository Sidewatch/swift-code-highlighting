import Foundation

/// The regex rule table shared by every language of the TeX family that has no table of its own.
extension RuleTables {
    static let texFamily: [(String, TokenKind)] = [
        ("%.*$", .comment),
        ("\\\\[A-Za-z@]+", .keyword),
        ("\\{[^{}]*\\}", .type),
        ("\\$[^$]*\\$", .string),
    ]
}
