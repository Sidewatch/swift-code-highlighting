//
//  YAMLRules.swift
//  CodeHighlighting
//
//  The regex rule table for YAML.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for YAML. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let yaml: [(String, TokenKind)] = [
        hashComment,
        doubleQuoted,
        singleQuotedPlain,
        ("^[a-zA-Z_][\\w.-]*:", .function),
        ("\\b(true|false|yes|no|null|~)\\b", .keyword),
        decimal,
    ]
}
