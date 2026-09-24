//
//  HighlightedHTML.swift
//  CodeHighlighting
//
//  Code as coloured HTML through the same three tiers the editor paints with.
//
//  Created by David Sherlock on 9/24/26.
//

import AppKit
import CodeLanguage

/// `code` as HTML for the inside of a `<code>` or a table cell, coloured the way the editor
/// colours it — the SAME three tiers in the same order: a tree-sitter grammar where one is
/// vendored, the single-file-component splitter for `.astro` / `.vue` / `.svelte`, and the regex
/// rule tables for everything else (SCSS, Less, Terraform, GraphQL…). Escaped either way, one
/// `<span>` per colour run, none for text in the default colour.
///
/// Until 24 Sep 2026 the only HTML entry was ``TreeSitterHighlighter/highlightedHTML(_:language:)``,
/// which answers nil for a language without a grammar — so the Quick Look preview and the
/// Markdown fences showed SCSS plain while the editor beside them coloured it.
public enum HighlightedHTML {
    /// The HTML for `code` as `language`, coloured with `colors` (the highlighter's installed
    /// provider by default — a tree-sitter grammar reads that one whatever is passed).
    @MainActor
    public static func render(_ code: String, language: Language, colors: TokenColorProviding = HighlightTheme.colors) -> String {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let storage = NSTextStorage(string: code, attributes: [.font: font, .foregroundColor: colors.foreground])
        storage.beginEditing()
        let full = NSRange(location: 0, length: storage.length)
        if let tree = TreeSitterHighlighter(language: language) {
            tree.highlight(storage, in: full)
        } else if let component = EmbeddedMarkupHighlighter(language: language, colors: colors) {
            component.highlight(storage, in: full)
        } else {
            SyntaxHighlighter(language: language, colors: colors).highlight(storage, in: full)
        }
        storage.endEditing()
        return spans(of: storage, fallback: colors.foreground)
    }

    /// Which tier `render` paints `language` with.
    public static func tier(for language: Language) -> Tier {
        if TreeSitterHighlighter.supports(language) { return .treeSitter }
        if EmbeddedMarkupHighlighter.supports(language) { return .embeddedMarkup }
        return .regex
    }

    /// The three tiers, in the order they are tried.
    public enum Tier: Sendable, Equatable { case treeSitter, embeddedMarkup, regex }

    /// The storage's text as HTML: one span per colour RUN, not per token, so adjacent characters
    /// sharing a colour collapse into one element and the markup stays close to the code's size.
    /// Text in `fallback` gets no span — the surrounding element already carries that colour.
    static func spans(of storage: NSTextStorage, fallback: NSColor) -> String {
        let ns = storage.string as NSString
        var out = ""
        out.reserveCapacity(ns.length * 2)
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: ns.length)) { value, range, _ in
            let text = TreeSitterHighlighter.escapeHTML(ns.substring(with: range))
            let color = (value as? NSColor) ?? fallback
            if color == fallback { out += text } else { out += "<span style=\"color:\(TreeSitterHighlighter.cssHex(color))\">\(text)</span>" }
        }
        return out
    }
}
