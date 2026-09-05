//
//  ConfigFamilyRules.swift
//  CodeHighlighting
//
//  The regex rule table shared by every language of the Config family that has no table of its
//  own.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table shared by every language of the Config family that has no table of its own.
extension RuleTables {
    static let configFamily: [(String, TokenKind)] = [
        ("</?[A-Za-z][\\w-]*", .keyword),
        ("^\\s*\\[[^\\]]*\\]", .keyword),
        ("^\\s*[A-Za-z_][\\w.-]*", .function),
        ("\\$\\{?\\w+\\}?", .type),
        ("%\\{[^}]*\\}", .type),
        ("(?i)\\b(on|off|true|false|yes|no|none|null|enabled|disabled)\\b", .number),
        decimal,
        doubleQuoted,
        singleQuotedPlain,
        hashComment,
        ("(?:^|\\s);.*$", .comment),
    ]
}
