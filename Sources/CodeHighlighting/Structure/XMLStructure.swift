//
//  XMLStructure.swift
//  CodeHighlighting
//
//  An XML document as ordered structure, read off the tree-sitter grammar vendored for highlighting.
//
//  Created by David Sherlock on 9/25/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import SwiftTreeSitter
import CodeLanguage
import DataConverter

/// An XML document as the structure a tree shows, read off the vendored tree-sitter-xml grammar:
/// the root element is a one-pair mapping, and an element maps its `@attributes` then its children
/// in file order, repeated child names gathered into one sequence (`tags.tag[0]`, `tags.tag[1]`).
/// A text-only element is its trimmed text (CDATA verbatim, predefined and numeric references
/// resolved); mixed content keeps its text under `#text`. Comments, processing instructions and
/// the DOCTYPE are dropped. Nil for a document with no root element.
public enum XMLStructure {
    /// One step of a path into the structure: a mapping key or a sequence index.
    public typealias PathComponent = StructuredEdit.PathComponent
    /// The ranges of a member's value and key, for replacing one token in place.
    public typealias EditSite = StructuredEdit.EditSite

    /// The document as structure, or nil when it has no root element.
    public static func value(of text: String) -> StructuredValue? { located(text)?.value }

    /// Where the member at `path` sits: an attribute's value with its quotes and its name (so a
    /// rename touches one token); a text element's content, trimmed, so the file's indentation
    /// survives a replacement (an empty `<a></a>` has an empty site between its tags; `<a/>` has
    /// none). An element's name is written twice and has no key site; a `#text` beside
    /// attributes has its span, one woven between child elements has none.
    public static func site(in text: String, path: [PathComponent]) -> EditSite? {
        guard !path.isEmpty else { return nil }
        return located(text)?.site(path: path)
    }

    // MARK: - Walking

    /// The document as a ``LocatedValue``, ranges and all; nil when there is nothing to read.
    static func located(_ text: String) -> LocatedValue? {
        guard let root = TreeSitterHighlighter.freshParseRoot(text, language: .xml) else { return nil }
        let ns = text as NSString
        guard let element = root.child(byFieldName: "root") ?? YAMLStructure.namedChildren(root).first(where: { $0.nodeType == "element" }) else { return nil }
        let (name, builder) = build(element, ns: ns)
        let document = LocatedBuilder(.mapping)
        document.pairs = [(name, nil, builder)]
        return document.frozen
    }

    /// The element's name and its structure.
    static func build(_ element: Node, ns: NSString) -> (name: String, value: LocatedBuilder) {
        let children = YAMLStructure.namedChildren(element)
        let tag = children.first { ["STag", "EmptyElemTag"].contains($0.nodeType ?? "") }
        let tagChildren = tag.map(YAMLStructure.namedChildren) ?? []
        let name = tagChildren.first { $0.nodeType == "Name" }.map { YAMLStructure.text($0, ns) } ?? ""
        var attributes: [(key: String, keyRange: NSRange?, value: LocatedBuilder)] = []
        for attribute in tagChildren where attribute.nodeType == "Attribute" {
            let parts = YAMLStructure.namedChildren(attribute)
            guard let attrName = parts.first(where: { $0.nodeType == "Name" }), let attrValue = parts.first(where: { $0.nodeType == "AttValue" }) else { continue }
            let raw = YAMLStructure.text(attrValue, ns)
            let inner = raw.count >= 2 ? String(raw.dropFirst().dropLast()) : raw
            attributes.append(("@" + YAMLStructure.text(attrName, ns), attrName.range, .scalar(.string(XMLEdit.decodedReferences(inner)), range: attrValue.range)))
        }
        // The content: text pieces and child elements in order.
        var text = ""
        var textSpan: NSRange?
        var elements: [(name: String, value: LocatedBuilder)] = []
        if let content = children.first(where: { $0.nodeType == "content" }) {
            for piece in YAMLStructure.namedChildren(content) {
                switch piece.nodeType ?? "" {
                case "CharData": text += YAMLStructure.text(piece, ns); textSpan = textSpan.map { NSUnionRange($0, piece.range) } ?? piece.range
                case "CharRef", "EntityRef": text += XMLEdit.decodedReferences(YAMLStructure.text(piece, ns)); textSpan = textSpan.map { NSUnionRange($0, piece.range) } ?? piece.range
                case "CDSect":
                    if let data = YAMLStructure.namedChildren(piece).first(where: { $0.nodeType == "CData" }) { text += YAMLStructure.text(data, ns) }
                    textSpan = textSpan.map { NSUnionRange($0, piece.range) } ?? piece.range
                case "element": elements.append(build(piece, ns: ns))
                default: continue   // Comment, PI
                }
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if attributes.isEmpty && elements.isEmpty {
            // A leaf: its text, at the trimmed span; an empty `<a></a>` between its tags; `<a/>` nowhere.
            let range: NSRange?
            if let span = textSpan { range = trimmedRange(of: ns.substring(with: span), at: span.location) }
            else if let open = tag, open.nodeType == "STag" { range = NSRange(location: NSMaxRange(open.range), length: 0) }
            else { range = nil }
            return (name, .scalar(.string(trimmed), range: range))
        }
        let builder = LocatedBuilder(.mapping, range: element.range)
        builder.pairs = attributes
        for (childName, value) in elements {
            if let i = builder.pairs.firstIndex(where: { $0.key == childName && $0.keyRange == nil }) {
                let existing = builder.pairs[i].value
                if existing.kind == .sequence { existing.items.append(value) }
                else { let sequence = LocatedBuilder(.sequence); sequence.items = [existing, value]; builder.pairs[i].value = sequence }
            } else {
                builder.pairs.append((childName, nil, value))
            }
        }
        if !trimmed.isEmpty {
            // Text beside attributes has one span to write into; text woven between child elements has none.
            let range = elements.isEmpty ? textSpan.map { trimmedRange(of: ns.substring(with: $0), at: $0.location) } : nil
            builder.pairs.append(("#text", nil, .scalar(.string(trimmed), range: range)))
        }
        return (name, builder)
    }

    /// The range of `s` without surrounding whitespace, offset by `base`.
    static func trimmedRange(of s: String, at base: Int) -> NSRange {
        let ns = s as NSString
        var start = 0, end = ns.length
        func white(_ i: Int) -> Bool { Unicode.Scalar(ns.character(at: i)).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false }
        while start < end, white(start) { start += 1 }
        while end > start, white(end - 1) { end -= 1 }
        return NSRange(location: base + start, length: end - start)
    }
}
