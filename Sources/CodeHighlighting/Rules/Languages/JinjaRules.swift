//
//  JinjaRules.swift
//  CodeHighlighting
//
//  The regex rule table for Jinja.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Jinja: `{# #}` comments, the `{% %}` and `{{ }}` delimiters, the tag words, `| filters`,
/// dotted lookups, plus the markup family's tags for the HTML around them. Written 25 Sep 2026
/// (the markup family gave it two roles).
extension RuleTables {
    static let jinja: [(String, TokenKind)] = [
        ("\\{#[\\s\\S]*?#\\}", .comment),
        htmlComment,
        doubleQuotedPlain,
        singleQuotedPlain,
        ("\\{%-?|-?%\\}|\\{\\{-?|-?\\}\\}", .keyword),
        keywords(["if", "elif", "else", "endif", "for", "endfor", "in", "set", "endset", "block", "endblock", "extends", "include", "import", "from", "as", "macro", "endmacro", "call", "endcall", "filter", "endfilter", "with", "endwith", "raw", "endraw", "autoescape", "endautoescape", "is", "not", "and", "or", "true", "false", "none", "True", "False", "None", "loop", "recursive", "scoped", "ignore", "missing", "context", "do", "trans", "endtrans", "pluralize"]),
        ("\\|\\s*[a-z_]\\w*", .function),
        ("\\b[a-zA-Z_]\\w*(\\.[a-zA-Z_]\\w*)+\\b", .property),
        ("</?[A-Za-z][\\w:-]*|/>|>", .keyword),
        ("\\b[A-Za-z-]+=", .attribute),
        ("\\b\\d+(\\.\\d+)?\\b", .number),
    ]
}
