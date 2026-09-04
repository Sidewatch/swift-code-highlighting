import Foundation

/// The regex rule table shared by every language of the RubyLike family that has no table of its own.
extension RuleTables {
    static let rubyLikeFamily: [(String, TokenKind)] = [
        hashComment,
        doubleQuoted,
        singleQuoted,
        keywords([
            "def", "end", "do", "class", "module", "defmodule", "if", "elsif", "else", "unless",
            "case", "when", "cond", "then", "while", "until", "for", "begin", "rescue", "ensure",
            "raise", "return", "yield", "require", "import", "include", "use", "self", "nil", "true",
            "false", "and", "or", "not", "fn", "defn", "let", "match",
        ]),
        (":[A-Za-z_]\\w*", .string),
        ("@{1,2}[A-Za-z_]\\w*", .type),
        decimal,
    ]
}
