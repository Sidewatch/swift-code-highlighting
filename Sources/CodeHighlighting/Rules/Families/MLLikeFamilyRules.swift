import Foundation

/// The regex rule table shared by every language of the MLLike family that has no table of its own.
extension RuleTables {
    static let mlLikeFamily: [(String, TokenKind)] = [
        dashComment,
        ("\\(\\*[\\s\\S]*?\\*\\)", .comment),
        ("\\{-[\\s\\S]*?-\\}", .comment),
        doubleQuoted,
        keywords([
            "let", "in", "module", "import", "open", "type", "data", "newtype", "class", "instance",
            "where", "match", "with", "case", "of", "if", "then", "else", "do", "fun",
            "function", "val", "rec", "and", "begin", "end", "deriving", "struct", "functor", "signature",
        ]),
        ("\\b[A-Z]\\w*\\b", .type),
        decimal,
    ]
}
