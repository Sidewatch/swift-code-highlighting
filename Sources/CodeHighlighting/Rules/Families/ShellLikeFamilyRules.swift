import Foundation

/// The regex rule table shared by every language of the ShellLike family that has no table of its own.
extension RuleTables {
    static let shellLikeFamily: [(String, TokenKind)] = [
        hashComment,
        doubleQuoted,
        singleQuotedPlain,
        keywords([
                "if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case",
                "esac", "in", "function", "return", "exit", "local", "export", "set", "unset", "source",
                "alias", "echo",
            ]),
        ("\\$\\{?[A-Za-z_]\\w*\\}?", .type),
        ("\\b\\d+\\b", .number),
    ]
}
