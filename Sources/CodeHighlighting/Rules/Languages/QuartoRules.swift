//
//  QuartoRules.swift
//  CodeHighlighting
//
//  The regex rule table for Quarto.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Quarto (and R Markdown's shape): Markdown plus `{r}` / `{python}` fences, `#|` chunk
/// options, inline `r …` code, `:::` fenced divs, the frontmatter's keys. Written 25 Sep 2026
/// (the sweep found two roles).
extension RuleTables {
    static let quarto: [(String, TokenKind)] = [
        ("^```\\{[^}]*\\}\\s*$|^```\\s*$", .keyword),
        ("^#\\|\\s*[\\w-]+:", .attribute),
        ("`r [^`]+`", .function),
        ("^:::+.*$", .keyword),
        ("^[\\w-]+:(?=\\s)", .property),
        ("^---\\s*$", .comment),
    ] + markdown
}
