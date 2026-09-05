//
//  SymbolVisibility.swift
//  CodeHighlighting
//
//  The languages whose project-wide definitions a file written in `host` may resolve to — or
//  nil when `host` has no symbol vocabulary of its own and must resolve NOTHING across files.
//
//  Created by David Sherlock on 9/2/26.
//

import Foundation
import CodeLanguage

extension SymbolQueries {

    /// The languages whose project-wide definitions a file written in `host` may
    /// resolve to — or nil when `host` has no symbol vocabulary of its own and must
    /// resolve NOTHING across files.
    ///
    /// The index is keyed by bare name, and a bare name says nothing about who is
    /// asking: `float` is a CSS property, a PHP method and a C type, and `container`
    /// is a CSS class, a PHP property and a Swift struct. Hover-doc, Go to
    /// Definition and the completion popup's project tier all pass the hovered or
    /// edited file's language through here before touching the table.
    ///
    /// The rules, smallest table that is still honest:
    /// - A language with its own symbol query sees itself.
    /// - JavaScript and TypeScript (and their JSX/TSX dialects) see each other —
    ///   one project imports across that line every day. The single-file
    ///   components whose scripts are JS/TS (`.vue`, `.svelte`, `.astro`) and
    ///   `.ejs` templates see the same set.
    /// - C and C++ share headers; Objective-C(++) includes them.
    /// - Templating hosts see the language they embed: Blade → PHP, ERB/Haml/Slim
    ///   → Ruby, JSP → Java.
    /// - Everything else — stylesheets, markup, Markdown, data files, config,
    ///   plain text — gets nil. A stylesheet has no cross-file symbols to offer
    ///   and none to borrow.
    public static func visibleLanguages(from host: Language) -> Set<Language>? {
        switch host {
        case .javascript, .typescript, .jsx, .tsx, .vue, .svelte, .astro, .ejs:
            return [.javascript, .typescript, .jsx, .tsx]
        case .c, .cpp, .objectivec, .objectivecpp:
            return [.c, .cpp]
        case .php, .blade:
            return [.php]
        case .ruby, .erb, .haml, .slim:
            return [.ruby]
        case .java, .jsp:
            return [.java]
        default:
            return sources[host] != nil ? [host] : nil
        }
    }
}
