//
//  RuleTables.swift
//  CodeHighlighting
//
//  The regex (pattern, kind) tables behind `SyntaxHighlighter` for languages that have no tree-
//  sitter grammar.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation
import CodeLanguage

/// The regex (pattern, kind) tables behind `SyntaxHighlighter` for languages that have no
/// tree-sitter grammar. One file per language under `Rules/Languages`, one per family under
/// `Rules/Families`; the shared builders live in `RuleTables+Builders.swift`.
enum RuleTables {

    /// The table for `lang`; languages without one fall through to their family's.
    static func table(for lang: Language) -> [(String, TokenKind)] {
        switch lang {
        case .swift: return swift
        case .python: return python
        case .javascript, .typescript: return javascript
        case .astro: return astro
        case .html: return html
        case .css: return css
        case .scss, .sass, .less: return scss
        case .json: return json
        case .rust: return rust
        case .go: return go
        case .kotlin: return kotlin
        case .php: return php
        case .csharp: return csharp
        case .dart: return dart
        case .markdown: return markdown
        case .bash: return bash
        case .dockerfile: return dockerfile
        case .yaml: return yaml
        case .xml: return xml
        case .sql: return sql
        case .c, .cpp: return c
        case .java: return java
        case .ruby: return ruby
        case .gettext: return gettext
        case .gitignore: return gitignore
        case .vue, .svelte: return vue
        case .terraform, .hcl: return terraform
        case .graphql: return graphql
        case .prisma: return prisma
        case .protobuf: return protobuf
        case .toml: return toml
        case .diff: return diff
        // 25 Sep 2026: every language a corpus sweep found flat or nearly flat got its own table.
        case .erlang: return erlang
        case .prolog: return prolog
        case .fortran: return fortran
        case .cobol: return cobol
        case .assembly: return assembly
        case .llvm: return llvm
        case .smalltalk: return smalltalk
        case .vbscript: return vbscript
        case .xquery: return xquery
        case .abap: return abap
        case .mermaid: return mermaid
        case .plantuml: return plantuml
        case .log: return log
        case .asciidoc: return asciidoc
        case .restructuredtext: return restructuredtext
        case .textile: return textile
        case .gitattributes: return gitattributes
        case .json5, .hjson: return json5
        case .nix: return nix
        case .pug, .haml, .slim: return indentedMarkup
        case .jinja: return jinja
        case .bibtex: return bibtex
        case .dot: return dot
        case .edgeql: return edgeql
        case .gomod: return gomod
        case .manifest: return manifest
        case .meson: return meson
        case .quarto, .rmarkdown: return quarto
        case .strings: return strings
        case .texinfo: return texinfo
        default: return table(for: lang.family)
        }
    }

    /// The table shared by every language of `family` that has none of its own.
    static func table(for family: HighlightFamily) -> [(String, TokenKind)] {
        switch family {
        case .cLike: return cLikeFamily
        case .rubyLike: return rubyLikeFamily
        case .lispLike: return lispLikeFamily
        case .mlLike: return mlLikeFamily
        case .shellLike: return shellLikeFamily
        case .markup: return markupFamily
        case .config: return configFamily
        case .sql: return sqlFamily
        case .tex: return texFamily
        case .data: return dataFamily
        case .plain: return plainFamily
        }
    }
}
