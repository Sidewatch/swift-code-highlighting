//
//  TextileRules.swift
//  CodeHighlighting
//
//  The regex rule table for Textile.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Textile: `h1.` headings and block signatures, *bold*, _italic_, @code@, "links":url,
/// !images!, list markers, table cells, {styles}. Written 25 Sep 2026 (the sweep found one role).
extension RuleTables {
    static let textile: [(String, TokenKind)] = [
        ("^h[1-6]\\.\\s.*$", .keyword),
        ("^(bq|bc|pre|p|notextile|fn\\d+|table)\\.+\\s", .keyword),
        ("^\\s*[*#]+\\s", .keyword),
        ("@[^@\\n]+@", .string),
        ("\"[^\"\\n]+\":\\S+", .function),
        ("![^!\\n]+!", .function),
        ("\\*[^*\\n]+\\*", .type),
        ("_[^_\\n]+_", .variable),
        ("\\{[^}\\n]*\\}", .attribute),
        ("\\|_?\\.?", .comment),
    ]
}
