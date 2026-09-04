import Foundation

/// The regex rule table shared by every language of the LispLike family that has no table of its own.
extension RuleTables {
    static let lispLikeFamily: [(String, TokenKind)] = [
        (";.*$", .comment),
        doubleQuoted,
        ("\\b(def\\w*|let\\*?|lambda|fn|defn|defmacro|defmethod|if|cond|when|unless|case|do|loop|recur|quote|require|import|ns)\\b", .keyword),
        ("#?:[A-Za-z_][\\w-]*", .type),
        decimal,
    ]
}
