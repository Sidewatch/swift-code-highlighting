//
//  VueRules.swift
//  CodeHighlighting
//
//  The regex rule table for Vue / Svelte.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

/// The regex rule table for Vue / Svelte. Order matters: earlier rules win overlaps.
extension RuleTables {
    static let vue: [(String, TokenKind)] = [
        // Single-file components: tags, interpolation, and framework directives /
        // blocks. The embedded <script>/<style> aren't separately parsed here.
        htmlComment,
        doubleQuoted,
        singleQuoted,
        ("\\{[#/:][^}]*\\}", .keyword),   // {#if}/{/each}/{:else} (Svelte)
        ("\\{\\{[^}]*\\}\\}", .property),   // {{ mustache }} (Vue)
        ("</?[A-Za-z][\\w.-]*", .keyword),   // tags
        ("v-[a-z-]+|@[a-z:.-]+|:[a-z-]+|(?:on|bind|use|class):[a-z]+", .attribute),   // directives
        decimal,
    ]
}
