//
//  CompletionItem.swift
//  CodeHighlighting
//

import Foundation
import CodeLanguage

/// One row of the completion popup: what gets inserted, plus the little that
/// makes the row readable at a glance. Presentation (icon, layout) is the
/// popup's job — this only says which tier the row came from.
public struct CompletionItem: Equatable {
    /// The identifier inserted when the row is accepted.
    public let text: String
    /// Definition kind, drawn as the row's icon. Nil for a buffer word — that
    /// tier is "a string that appears in this file", not a definition.
    public let kind: SymbolKind?
    /// The defining file, drawn as the row's trailing label. Set only for the
    /// project tier: a current-file symbol's file is the one already on screen,
    /// and a buffer word has no definition site.
    public let detail: String?

    public init(text: String, kind: SymbolKind?, detail: String?) {
        self.text = text
        self.kind = kind
        self.detail = detail
    }
}
