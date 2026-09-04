//
//  DefLocation.swift
//  CodeHighlighting
//

import Foundation
import CodeLanguage

/// A definition found somewhere in the project.
public struct DefLocation: Sendable {
    /// The file the definition lives in.
    public let url: URL
    /// The identifier as written at the definition site.
    public let name: String
    /// What kind of definition this is.
    public let kind: SymbolKind
    /// The name identifier's range within that file.
    public let range: NSRange
    /// 1-based line of the definition.
    public let line: Int
    /// The type this member belongs to (innermost enclosing type at scan time),
    /// nil for free functions/types and for languages whose methods don't nest
    /// (Go receivers, C++ out-of-line). Lets go-to-definition prefer the class
    /// the call site's receiver actually holds.
    public let owner: String?
    /// The language the defining file parsed as. Cross-file lookups are gated on it
    /// (see ``ProjectSymbolIndex/definitions(of:visibleFrom:)``): a symbol table
    /// keyed by bare name alone let a CSS file's `float` resolve to a PHP method.
    public let language: Language
}
