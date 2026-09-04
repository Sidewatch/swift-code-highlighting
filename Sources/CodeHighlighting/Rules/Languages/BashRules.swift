import Foundation

/// The regex rule table for Bash. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let bash: [(String, TokenKind)] = [
        hashComment,
        doubleQuoted,
        singleQuotedPlain,
        keywords([
                "if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case",
                "esac", "in", "function", "return", "exit", "local", "export", "source", "alias", "read",
                "set", "unset", "shift", "trap",
            ]),
        ("\\$\\{?[a-zA-Z_]\\w*\\}?", .type),
        decimal,
        functions([
                "echo", "cd", "ls", "pwd", "mkdir", "rm", "cp", "mv", "cat", "grep",
                "sed", "awk", "find", "sort", "chmod", "curl", "wget", "git",
            ]),
    ]
}
