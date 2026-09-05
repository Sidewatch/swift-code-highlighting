//
//  SymbolIndex.swift
//  CodeHighlighting
//
//  A definition found in a source file (function, class, method, …).
//
//  Created by David Sherlock on 7/9/26.
//

import Foundation
import CodeLanguage

/// A definition found in a source file (function, class, method, …).
public struct Symbol {
    /// The identifier as written at the definition site.
    public let name: String
    /// What kind of definition this is.
    public let kind: SymbolKind
    /// The name identifier's range in the file (for jump + scroll).
    public let range: NSRange
    /// 1-based line of the definition.
    public let line: Int

    /// The enclosing definition's full range (the type/function *body*, not just the
    /// name) — a symbol whose `range` falls inside another's `scopeRange` is its child,
    /// which is how the outline tree nests methods under their type. Nil when unknown.
    public let scopeRange: NSRange?

    public init(name: String, kind: SymbolKind, range: NSRange, line: Int, scopeRange: NSRange? = nil) {
        self.name = name
        self.kind = kind
        self.range = range
        self.line = line
        self.scopeRange = scopeRange
    }
}
