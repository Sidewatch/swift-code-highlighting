import Foundation

/// The regex rule table for Gitignore. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let gitignore: [(String, TokenKind)] = [
        // No dedicated grammar, so give ignore files (.gitignore/.dockerignore/
        // .npmignore/…) real coloring: comment lines, the `!` un-ignore prefix,
        // and glob metacharacters (`*`, `**`, `?`, and `[ranges]`).
        hashComment,
        ("^\\s*!", .keyword),
        ("\\*\\*|\\*|\\?", .type),
        ("\\[[^\\]]*\\]", .type),
    ]
}
