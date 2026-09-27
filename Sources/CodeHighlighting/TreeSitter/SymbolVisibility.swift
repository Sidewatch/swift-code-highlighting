//
//  SymbolVisibility.swift
//  CodeHighlighting
//
//  The languages whose project-wide definitions a file written in `host` may resolve to — or
//  nil when `host` has no symbol vocabulary of its own and must resolve NOTHING across files.
//
//  Created by David Sherlock on 9/2/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import CodeLanguage

extension SymbolQueries {

    /// The languages whose project-wide definitions a file written in `host` may resolve to, or
    /// nil when `host` must resolve nothing across files. The index is keyed by bare name, and
    /// `float` is a CSS property, a PHP method and a C type. A language with a symbol query sees
    /// itself; JS/TS and their dialects (plus `.vue`, `.svelte`, `.astro`, `.ejs`) see each other;
    /// C, C++ and Objective-C share headers; templates see what they embed (Blade → PHP, ERB → Ruby,
    /// JSP → Java). Stylesheets, markup, data and plain text get nil.
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
