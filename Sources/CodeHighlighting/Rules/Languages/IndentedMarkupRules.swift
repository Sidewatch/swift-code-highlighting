//
//  IndentedMarkupRules.swift
//  CodeHighlighting
//
//  The regex rule table for Pug, Haml and Slim.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// The indented template languages — Pug, Haml, Slim: comment lines, tags at the start of a
/// line (Haml's `%tag`), `.class` / `#id` shorthands, `(attributes)`, the control words, `-` and
/// `=` code lines, `#{…}` interpolation, `|` piped text, `+mixin` calls. Written 25 Sep 2026 (the
/// markup family gave them two roles).
extension RuleTables {
    static let indentedMarkup: [(String, TokenKind)] = [
        ("^\\s*(//-?|-#|/!?)\\s.*$", .comment),
        ("^\\s*(//-?|-#)$", .comment),
        ("#\\{[^}]*\\}|\\$\\{[^}]*\\}|!\\{[^}]*\\}", .property),
        doubleQuotedPlain,
        singleQuotedPlain,
        ("^\\s*\\|.*$", .string),
        ("^\\s*(doctype|!!!)\\b.*$", .keyword),
        ("\\b(if|else|elif|elsif|unless|each|for|in|of|while|case|when|default|mixin|include|extends|block|append|prepend|yield|end|do|render|javascript|css|coffee|markdown|sass|scss)\\b", .keyword),
        ("^\\s*%[\\w:-]+", .keyword),
        ("^\\s*[a-z][\\w:-]*(?=[\\s.#(=:]|$)", .keyword),
        ("[.#][A-Za-z_][\\w-]*", .type),
        ("\\+[\\w-]+", .function),
        ("\\b[\\w:-]+(?==)", .attribute),
        ("^\\s*[-=!]=?", .variable),
        ("\\b\\d+(\\.\\d+)?\\b", .number),
    ]
}
