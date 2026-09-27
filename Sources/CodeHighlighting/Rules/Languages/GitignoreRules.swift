//
//  GitignoreRules.swift
//  CodeHighlighting
//
//  The regex rule table for Gitignore.
//
//  Created by David Sherlock on 9/5/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// The regex rule table for Gitignore.
/// Later rules repaint earlier ones; strings and comments paint last.
extension RuleTables {
    static let gitignore: [(String, TokenKind)] = [
        // No dedicated grammar, so give ignore files (.gitignore/.dockerignore/
        // .npmignore/…) real colouring: comment lines, the `!` un-ignore prefix,
        // and glob metacharacters (`*`, `**`, `?`, and `[ranges]`).
        hashComment,
        ("^\\s*!", .keyword),
        ("\\*\\*|\\*|\\?", .type),
        ("\\[[^\\]]*\\]", .type),
    ]
}
