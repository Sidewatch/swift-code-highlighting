import Foundation

/// The regex rule table shared by every language of the Markup family that has no table of its own.
extension RuleTables {
    static let markupFamily: [(String, TokenKind)] = [
        htmlComment,
        doubleQuotedPlain,
        singleQuotedPlain,
        ("</?[A-Za-z][\\w:-]*", .keyword),
        ("/>|>", .keyword),
        ("\\b[A-Za-z-]+=", .function),
    ]
}
