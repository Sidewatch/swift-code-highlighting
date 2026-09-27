//
//  YAMLStructure+Edit.swift
//  CodeHighlighting
//
//  Where one key or value sits in a YAML file, and how a typed replacement is written.
//
//  Created by David Sherlock on 9/25/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import SwiftTreeSitter
import DataConverter

/// Where one key or value of a YAML file sits: the finding half of a cell edit in the YAML tree.
/// `site(in:path:)` walks the same nodes as `value(of:)` and answers the UTF-16 ranges of the
/// member's scalar (quotes or `|` block included) and, in a mapping, its key. What to write there
/// lives in swift-data-converter (`YAMLEdit.encodedScalar`), sharing JSON's escaper.
extension YAMLStructure {
    /// One step of a path: a mapping member by key, or a sequence element by index.
    public typealias PathComponent = StructuredEdit.PathComponent
    /// The ranges of a member: its value, and its key when it sits in a mapping.
    public typealias EditSite = StructuredEdit.EditSite

    /// The member at `path` in the first document of `text`, or nil.
    public static func site(in text: String, path: [PathComponent]) -> EditSite? {
        guard !path.isEmpty, let root = TreeSitterHighlighter.freshParseRoot(text, language: .yaml) else { return nil }
        let ns = text as NSString
        guard let doc = namedChildren(root).first(where: { $0.nodeType == "document" }),
              let body = namedChildren(doc).first(where: { ["block_node", "flow_node"].contains($0.nodeType ?? "") }) else { return nil }
        return find(body, path: path[...], ns: ns)
    }

    // MARK: - Walking

    private static func unwrap(_ node: Node) -> Node {
        var n = node
        while ["block_node", "flow_node"].contains(n.nodeType ?? ""),
              let inner = namedChildren(n).first(where: { !["anchor", "tag", "comment"].contains($0.nodeType ?? "") }) { n = inner }
        return n
    }

    private static func find(_ node: Node, path: ArraySlice<PathComponent>, ns: NSString) -> EditSite? {
        let n = unwrap(node)
        guard let step = path.first else { return nil }
        switch n.nodeType ?? "" {
        case "block_mapping", "flow_mapping":
            guard case .key(let wanted) = step else { return nil }
            for pair in namedChildren(n) where ["block_mapping_pair", "flow_pair"].contains(pair.nodeType ?? "") {
                guard let keyNode = pair.child(byFieldName: "key"), keyText(convert(keyNode, ns: ns)) == wanted else { continue }
                let keyRange = unwrap(keyNode).range
                guard let valueNode = pair.child(byFieldName: "value") else {
                    return path.count == 1 ? EditSite(key: keyRange, value: NSRange(location: NSMaxRange(pair.range), length: 0)) : nil
                }
                if path.count == 1 { return EditSite(key: keyRange, value: unwrap(valueNode).range) }
                return find(valueNode, path: path.dropFirst(), ns: ns)
            }
            return nil
        case "block_sequence":
            guard case .index(let i) = step else { return nil }
            let items = namedChildren(n).filter { $0.nodeType == "block_sequence_item" }
            guard items.indices.contains(i), let inner = namedChildren(items[i]).first(where: { $0.nodeType != "comment" }) else { return nil }
            if path.count == 1 { return EditSite(key: nil, value: unwrap(inner).range) }
            return find(inner, path: path.dropFirst(), ns: ns)
        case "flow_sequence":
            guard case .index(let i) = step else { return nil }
            let items = namedChildren(n).filter { $0.nodeType != "comment" }
            guard items.indices.contains(i) else { return nil }
            if path.count == 1 { return EditSite(key: nil, value: unwrap(items[i]).range) }
            return find(items[i], path: path.dropFirst(), ns: ns)
        default:
            return nil
        }
    }
}
