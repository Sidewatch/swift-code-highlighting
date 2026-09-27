//
//  ManifestRules.swift
//  CodeHighlighting
//
//  The regex rule table for JAR manifests.
//
//  Created by David Sherlock on 9/25/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// `MANIFEST.MF`: `Name:` keys, continuation lines, jar paths, dotted class names, versions.
extension RuleTables {
    static let manifest: [(String, TokenKind)] = [
        ("^[A-Za-z][\\w-]*(?=:)", .property),
        ("^ .*$", .string),
        ("\\b[\\w./-]+\\.(jar|zip|war)\\b", .string),
        ("\\b[a-z][\\w]*(\\.[a-z][\\w]*)+\\.[A-Z]\\w*\\b", .type),
        ("\\b[a-z][\\w]*(\\.[a-z][\\w]*)+\\b", .function),
        ("\\b\\d+(\\.\\d+)+\\b|\\b\\d+\\b", .number),
        ("\\b(true|false)\\b", .keyword),
    ]
}
