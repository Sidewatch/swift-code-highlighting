//
//  LocatedValue.swift
//  CodeHighlighting
//
//  A document's structure with where each key and value sits — one walk that answers both the tree and an edit site.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation
import DataConverter

/// A value and where it sits in its file (25 Sep 2026): the one thing a grammar walk produces,
/// from which `value` (the tree) and `site(path:)` (a cell edit's ranges) are both read — so
/// the two can never disagree about which node a path names. The TOML, XML and property-list
/// readers build one; YAML's two walks predate it.
struct LocatedValue {
    indirect enum Node {
        case mapping([LocatedPair])
        case sequence([LocatedValue])
        case scalar(StructuredValue)
    }
    var node: Node
    /// The value's own span: a scalar's token, a container's extent — nil when a container has
    /// no single span (a TOML table gathered from several headers) or a scalar no place to write
    /// (the text of `<empty/>`).
    var range: NSRange?

    /// The tree's value, ranges dropped.
    var value: StructuredValue {
        switch node {
        case .mapping(let pairs): return .mapping(pairs.map { StructuredPair(key: $0.key, value: $0.value.value) })
        case .sequence(let items): return .sequence(items.map(\.value))
        case .scalar(let v): return v
        }
    }

    /// The member at `path`: its value's range and, in a mapping, its key's. Nil when nothing
    /// sits there or the value has nowhere to be written.
    func site(path: [StructuredEdit.PathComponent]) -> StructuredEdit.EditSite? { site(path: path[...], keyRange: nil) }

    private func site(path: ArraySlice<StructuredEdit.PathComponent>, keyRange: NSRange?) -> StructuredEdit.EditSite? {
        guard let step = path.first else {
            guard let range = range ?? keyRange.map({ NSRange(location: NSMaxRange($0), length: 0) }) else { return nil }
            return StructuredEdit.EditSite(key: keyRange, value: range)
        }
        switch (node, step) {
        case (.mapping(let pairs), .key(let key)):
            guard let pair = pairs.first(where: { $0.key == key }) else { return nil }
            return pair.value.site(path: path.dropFirst(), keyRange: pair.keyRange)
        case (.sequence(let items), .index(let i)):
            guard items.indices.contains(i) else { return nil }
            return items[i].site(path: path.dropFirst(), keyRange: nil)
        default:
            return nil
        }
    }
}

/// One `key: value` of a located mapping; `keyRange` is nil when the key cannot be renamed on
/// its own (an XML element's name is written twice, a gathered `#text`).
struct LocatedPair {
    let key: String
    let keyRange: NSRange?
    var value: LocatedValue
}

/// A located value under construction: the readers grow one as they walk, then freeze it.
final class LocatedBuilder {
    enum Kind { case mapping, sequence, scalar }
    let kind: Kind
    var pairs: [(key: String, keyRange: NSRange?, value: LocatedBuilder)] = []
    var items: [LocatedBuilder] = []
    var scalar: StructuredValue = .null
    var range: NSRange?

    init(_ kind: Kind, range: NSRange? = nil) { self.kind = kind; self.range = range }
    static func scalar(_ value: StructuredValue, range: NSRange?) -> LocatedBuilder {
        let b = LocatedBuilder(.scalar, range: range); b.scalar = value; return b
    }

    /// The mapping member named `key`, made as `kind` when absent. A sequence member (an array
    /// of tables) answers its LAST element, where TOML's next pair belongs.
    func member(_ key: String, keyRange: NSRange?, orMake kind: Kind) -> LocatedBuilder {
        if let existing = pairs.first(where: { $0.key == key })?.value {
            if existing.kind == .sequence, kind == .mapping, let last = existing.items.last { return last }
            if existing.kind == kind { return existing }
        }
        let made = LocatedBuilder(kind)
        pairs.append((key, keyRange, made))
        return made
    }

    var frozen: LocatedValue {
        switch kind {
        case .mapping: return LocatedValue(node: .mapping(pairs.map { LocatedPair(key: $0.key, keyRange: $0.keyRange, value: $0.value.frozen) }), range: range)
        case .sequence: return LocatedValue(node: .sequence(items.map(\.frozen)), range: range)
        case .scalar: return LocatedValue(node: .scalar(scalar), range: range)
        }
    }
}
