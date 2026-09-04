import Foundation

/// The regex rule table shared by every language of the SQL family that has no table of its own.
extension RuleTables {
    static let sqlFamily: [(String, TokenKind)] = [
        dashComment,
        blockComment,
        ("'(?:[^']|'')*'", .string),
        ("(?i)\\b(select|from|where|insert|into|values|update|set|delete|create|table|view|index|drop|alter|add|join|left|right|inner|outer|full|cross|on|using|group|by|order|asc|desc|having|limit|offset|distinct|union|all|as|and|or|not|null|is|in|between|like|primary|key|foreign|references|default|unique|check|case|when|then|else|end|begin|commit|rollback)\\b", .keyword),
        decimal,
        ("\\b([A-Za-z_]\\w*)\\s*\\(", .function),
    ]
}
