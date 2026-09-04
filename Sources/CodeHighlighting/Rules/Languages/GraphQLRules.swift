import Foundation

/// The regex rule table for GraphQL. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let graphql: [(String, TokenKind)] = [
        hashComment,
        doubleQuoted,
        keywords([
                "type", "query", "mutation", "subscription", "input", "enum", "interface", "union", "scalar", "fragment",
                "schema", "extend", "directive", "implements", "on",
            ]),
        ("@\\w+", .attribute),   // @directives
        ("\\$[A-Za-z_]\\w*", .property),   // $variables
        ("\\b[A-Z]\\w*\\b", .type),   // Types
        decimal,
    ]
}
