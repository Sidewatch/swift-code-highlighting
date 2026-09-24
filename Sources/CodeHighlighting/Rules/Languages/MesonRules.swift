//
//  MesonRules.swift
//  CodeHighlighting
//
//  The regex rule table for Meson.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Meson: `#` comments, `'…'` strings, the build functions and control words, `kwarg :`
/// names, method calls, the built-in objects. Written 25 Sep 2026 (the sweep found two roles).
extension RuleTables {
    static let meson: [(String, TokenKind)] = [
        hashComment,
        ("'''[\\s\\S]*?'''", .string),
        singleQuoted,
        keywords(["if", "elif", "else", "endif", "foreach", "endforeach", "and", "or", "not", "in", "true", "false", "break", "continue"]),
        ("\\b(meson|host_machine|build_machine|target_machine)\\b", .type),
        ("\\b[a-z_]\\w*(?=\\s*:)", .attribute),
        ("\\.[a-z_]\\w*(?=\\()", .function),
        ("\\b[a-z_]\\w*(?=\\()", .function),
        ("\\b\\d+\\b", .number),
    ]
}
