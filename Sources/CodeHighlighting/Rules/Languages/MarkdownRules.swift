import Foundation

/// The regex rule table for Markdown. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let markdown: [(String, TokenKind)] = [
        ("^>+\\s?.*$", .comment),
        ("^\\s*(\\*{3,}|-{3,}|_{3,})\\s*$", .comment),
        ("^\\s*[\\-\\*+]\\s", .keyword),
        ("^\\s*\\d+\\.\\s", .keyword),
        ("!?\\[([^\\]]+)\\]\\(([^)]+)\\)", .type),
        ("(?<!\\*)\\*(?![\\s*])[^*\\n]+?(?<![\\s*])\\*(?!\\*)", .type),
        ("(?<!\\w)_(?![\\s_])[^_\\n]+?(?<![\\s_])_(?!\\w)", .type),
        ("\\*\\*(?:[^*\\n]|\\*(?!\\*))+?\\*\\*", .function),
        ("__(?:[^_\\n]|_(?!_))+?__", .function),
        ("^#{1,6}\\s+.*$", .keyword),
        ("`[^`\\n]+`", .string),
        ("```[\\s\\S]*?```", .string),
    ]
}
