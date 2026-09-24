//
//  PlistStructure.swift
//  CodeHighlighting
//
//  An XML property list as ordered structure with edit sites; a binary one through Foundation.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation
import SwiftTreeSitter
import CodeLanguage
import DataConverter

/// A property list as the structure a tree shows (25 Sep 2026): an XML plist (`Info.plist`,
/// `.entitlements`, an Xcode-written `.strings`) read off the vendored tree-sitter-xml grammar
/// so a `<dict>` keeps the file's key order and every key and value has a site to edit — a
/// `<key>` then its element: `<string>`, `<date>` and `<data>` as strings (data with its
/// whitespace removed), `<integer>` and `<real>` as numbers, `<true/>` / `<false/>` as booleans,
/// `<array>` a sequence, `<dict>` a mapping; a BINARY plist (`bplist00`) through
/// `PropertyListStructure` in swift-data-converter, keys sorted and nothing editable, since
/// there is no text to write into. A `<plist>` wrapper is unwrapped; a bare `<dict>` or
/// `<array>` root is taken as is. Nil for anything else.
public enum PlistStructure {
    public typealias PathComponent = StructuredEdit.PathComponent
    public typealias EditSite = StructuredEdit.EditSite

    /// The document as structure, or nil when it is not a property list.
    public static func value(of text: String) -> StructuredValue? {
        if let data = binaryData(text) { return PropertyListStructure.value(of: data) }
        return located(text)?.value
    }

    /// The document's bytes as structure: binary through Foundation, XML through the grammar.
    public static func value(of data: Data) -> StructuredValue? {
        if PropertyListStructure.isBinary(data.prefix(8)) { return PropertyListStructure.value(of: data) }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return located(text)?.value
    }

    /// Where the member at `path` sits in an XML plist: a key's text, a scalar's content
    /// (trimmed; a boolean's site is its whole `<true/>` element, so a replacement can change
    /// the element). Nil for a binary plist.
    public static func site(in text: String, path: [PathComponent]) -> EditSite? {
        guard !path.isEmpty, binaryData(text) == nil else { return nil }
        return located(text)?.site(path: path)
    }

    /// A binary plist that was opened as text (Latin-1 round-trips every byte) — its bytes back.
    static func binaryData(_ text: String) -> Data? {
        guard text.hasPrefix("bplist") else { return nil }
        return text.data(using: .isoLatin1) ?? text.data(using: .utf8)
    }

    // MARK: - Walking

    static func located(_ text: String) -> LocatedValue? {
        guard let root = TreeSitterHighlighter.freshParseRoot(text, language: .xml) else { return nil }
        let ns = text as NSString
        guard var element = root.child(byFieldName: "root") ?? YAMLStructure.namedChildren(root).first(where: { $0.nodeType == "element" }) else { return nil }
        if name(of: element, ns) == "plist" {
            guard let inner = childElements(of: element).first else { return nil }
            element = inner
        }
        guard ["dict", "array"].contains(name(of: element, ns)) else { return nil }
        return build(element, ns: ns).frozen
    }

    private static func name(of element: Node, _ ns: NSString) -> String {
        let tag = YAMLStructure.namedChildren(element).first { ["STag", "EmptyElemTag"].contains($0.nodeType ?? "") }
        return tag.flatMap { YAMLStructure.namedChildren($0).first { $0.nodeType == "Name" } }.map { YAMLStructure.text($0, ns) } ?? ""
    }

    private static func childElements(of element: Node) -> [Node] {
        guard let content = YAMLStructure.namedChildren(element).first(where: { $0.nodeType == "content" }) else { return [] }
        return YAMLStructure.namedChildren(content).filter { $0.nodeType == "element" }
    }

    /// The element's raw text content (references resolved) and the trimmed span it sits in;
    /// an empty `<string></string>` has an empty span between its tags, `<string/>` none.
    private static func content(of element: Node, ns: NSString) -> (text: String, range: NSRange?) {
        let children = YAMLStructure.namedChildren(element)
        guard let content = children.first(where: { $0.nodeType == "content" }) else {
            let open = children.first { $0.nodeType == "STag" }
            return ("", open.map { NSRange(location: NSMaxRange($0.range), length: 0) })
        }
        var text = ""
        for piece in YAMLStructure.namedChildren(content) {
            switch piece.nodeType ?? "" {
            case "CharData": text += YAMLStructure.text(piece, ns)
            case "CharRef", "EntityRef": text += XMLEdit.decodedReferences(YAMLStructure.text(piece, ns))
            case "CDSect": if let data = YAMLStructure.namedChildren(piece).first(where: { $0.nodeType == "CData" }) { text += YAMLStructure.text(data, ns) }
            default: continue
            }
        }
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), XMLStructure.trimmedRange(of: ns.substring(with: content.range), at: content.range.location))
    }

    private static func build(_ element: Node, ns: NSString) -> LocatedBuilder {
        switch name(of: element, ns) {
        case "dict":
            let builder = LocatedBuilder(.mapping, range: element.range)
            let elements = childElements(of: element)
            var i = 0
            while i + 1 < elements.count {
                guard name(of: elements[i], ns) == "key" else { i += 1; continue }
                let key = content(of: elements[i], ns: ns)
                builder.pairs.append((key.text, key.range, build(elements[i + 1], ns: ns)))
                i += 2
            }
            return builder
        case "array":
            let builder = LocatedBuilder(.sequence, range: element.range)
            builder.items = childElements(of: element).map { build($0, ns: ns) }
            return builder
        case "integer":
            let c = content(of: element, ns: ns)
            return .scalar(Int(c.text).map { .integer($0) } ?? .string(c.text), range: c.range)
        case "real":
            let c = content(of: element, ns: ns)
            return .scalar(Double(c.text).map { .number($0) } ?? .string(c.text), range: c.range)
        case "true": return .scalar(.bool(true), range: element.range)
        case "false": return .scalar(.bool(false), range: element.range)
        case "data":
            let c = content(of: element, ns: ns)
            return .scalar(.string(c.text.filter { !$0.isWhitespace }), range: c.range)
        default:   // string, date, and anything else: its text
            let c = content(of: element, ns: ns)
            return .scalar(.string(c.text), range: c.range)
        }
    }
}
