//
//  GoModRules.swift
//  CodeHighlighting
//
//  The regex rule table for go.mod.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// `go.mod` / `go.sum`: `//` comments (`// indirect`), the directive words, module paths,
/// `vX.Y.Z` versions, `=>` replacements, the Go version. Written 25 Sep 2026 (the sweep found two roles).
extension RuleTables {
    static let gomod: [(String, TokenKind)] = [
        lineComment,
        keywords(["module", "go", "toolchain", "require", "replace", "exclude", "retract", "indirect", "godebug"]),
        ("=>", .type),
        ("\\bv\\d+\\.\\d+\\.\\d+[\\w.+-]*", .number),
        ("\\b\\d+\\.\\d+(\\.\\d+)?\\b", .number),
        ("\\b[\\w.-]+(/[\\w.-]+)+\\b", .string),
        ("\\bh1:[A-Za-z0-9+/=]+", .property),
    ]
}
