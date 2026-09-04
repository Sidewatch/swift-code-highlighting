import Foundation

/// The regex rule table for HTML. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let html: [(String, TokenKind)] = [
        htmlComment,
        doubleQuotedPlain,
        singleQuotedPlain,
        ("</?[a-zA-Z][\\w-]*", .keyword),
        ("/>|>", .keyword),
        ("\\b[a-zA-Z-]+=", .function),
    ]
}
