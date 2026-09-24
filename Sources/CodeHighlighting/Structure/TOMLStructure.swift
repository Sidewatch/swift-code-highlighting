//
//  TOMLStructure.swift
//  CodeHighlighting
//
//  A TOML document as ordered structure, read off the tree-sitter grammar vendored for highlighting.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation
import SwiftTreeSitter
import CodeLanguage
import DataConverter

/// A TOML document as the structure a tree shows (25 Sep 2026, David: "I guess TOML and some
/// other formats too"), from the vendored tree-sitter-toml grammar — so no second parser.
/// `[table]` and `[a.b.c]` headers open nested mappings, `[[array]]` headers append a mapping
/// to a sequence, dotted keys nest, and pairs land in file order under whatever header is
/// open. Scalars keep their TOML kind: integers in every base with `_` separators, floats
/// (`inf` and `nan` stay strings), booleans, the four date-time forms as strings, strings with
/// their escapes resolved and multi-line strings with their first newline and line-ending
/// backslashes handled. Arrays are sequences, inline tables mappings. Tree-sitter parses
/// anything, so a malformed file yields what it could read; nil only for an empty document or
/// a missing grammar.
public enum TOMLStructure {
    public typealias PathComponent = StructuredEdit.PathComponent
    public typealias EditSite = StructuredEdit.EditSite

    /// The document as structure, or nil when it is empty.
    public static func value(of text: String) -> StructuredValue? {
        guard let located = located(text), case .mapping(let pairs) = located.node, !pairs.isEmpty else { return nil }
        return located.value
    }

    /// Where the member at `path` sits: its value (a string's quotes included), and its key —
    /// the last segment of a dotted key or a table header, so a rename touches one token.
    public static func site(in text: String, path: [PathComponent]) -> EditSite? {
        guard !path.isEmpty else { return nil }
        return located(text)?.site(path: path)
    }

    // MARK: - Walking

    static func located(_ text: String) -> LocatedValue? {
        guard let root = TreeSitterHighlighter.freshParseRoot(text, language: .toml) else { return nil }
        let ns = text as NSString
        let document = LocatedBuilder(.mapping)
        var current = document
        for child in YAMLStructure.namedChildren(root) {
            switch child.nodeType ?? "" {
            case "table":
                guard let header = YAMLStructure.namedChildren(child).first(where: isKey) else { continue }
                current = descend(document, keyPath(header, ns), last: .mapping)
                addPairs(of: child, into: current, ns: ns)
            case "table_array_element":
                guard let header = YAMLStructure.namedChildren(child).first(where: isKey) else { continue }
                let segments = keyPath(header, ns)
                let parent = descend(document, Array(segments.dropLast()), last: .mapping)
                guard let last = segments.last else { continue }
                let sequence = parent.member(last.text, keyRange: last.range, orMake: .sequence)
                let element = LocatedBuilder(.mapping)
                sequence.items.append(element)
                current = element
                addPairs(of: child, into: current, ns: ns)
            case "pair":
                addPair(child, into: current, ns: ns)
            default:
                continue
            }
        }
        return document.frozen
    }

    private static func isKey(_ node: Node) -> Bool { ["bare_key", "quoted_key", "dotted_key"].contains(node.nodeType ?? "") }

    /// The mapping at `segments` under `table`, making mappings on the way; the last segment is
    /// made as `last`.
    private static func descend(_ table: LocatedBuilder, _ segments: [(text: String, range: NSRange)], last: LocatedBuilder.Kind) -> LocatedBuilder {
        var current = table
        for (i, segment) in segments.enumerated() {
            current = current.member(segment.text, keyRange: segment.range, orMake: i == segments.count - 1 ? last : .mapping)
        }
        return current
    }

    private static func addPairs(of node: Node, into table: LocatedBuilder, ns: NSString) {
        for pair in YAMLStructure.namedChildren(node) where pair.nodeType == "pair" { addPair(pair, into: table, ns: ns) }
    }

    private static func addPair(_ pair: Node, into table: LocatedBuilder, ns: NSString) {
        let children = YAMLStructure.namedChildren(pair)
        guard let keyNode = children.first(where: isKey), let valueNode = children.first(where: { !isKey($0) && $0.nodeType != "comment" }) else { return }
        let segments = keyPath(keyNode, ns)
        guard let last = segments.last else { return }
        let parent = descend(table, Array(segments.dropLast()), last: .mapping)
        parent.pairs.append((last.text, last.range, build(valueNode, ns: ns)))
    }

    /// A key's segments in order: `a.b."c d"` is three, each with its own range.
    private static func keyPath(_ node: Node, _ ns: NSString) -> [(text: String, range: NSRange)] {
        switch node.nodeType ?? "" {
        case "dotted_key": return YAMLStructure.namedChildren(node).flatMap { keyPath($0, ns) }
        case "quoted_key": return [(unquoted(YAMLStructure.text(node, ns)), node.range)]
        default: return [(YAMLStructure.text(node, ns), node.range)]
        }
    }

    private static func build(_ node: Node, ns: NSString) -> LocatedBuilder {
        let raw = YAMLStructure.text(node, ns)
        switch node.nodeType ?? "" {
        case "array":
            let b = LocatedBuilder(.sequence, range: node.range)
            b.items = YAMLStructure.namedChildren(node).filter { $0.nodeType != "comment" }.map { build($0, ns: ns) }
            return b
        case "inline_table":
            let b = LocatedBuilder(.mapping, range: node.range)
            addPairs(of: node, into: b, ns: ns)
            return b
        case "string": return .scalar(.string(unquoted(raw)), range: node.range)
        case "integer": return .scalar(integer(raw), range: node.range)
        case "float":
            let plain = raw.replacingOccurrences(of: "_", with: "")
            if plain.lowercased().contains("inf") || plain.lowercased().contains("nan") { return .scalar(.string(raw), range: node.range) }
            return .scalar(Double(plain).map { .number($0) } ?? .string(raw), range: node.range)
        case "boolean": return .scalar(.bool(raw == "true"), range: node.range)
        default: return .scalar(.string(raw), range: node.range)   // the date-time forms, and anything new
        }
    }

    /// An integer in any of TOML's bases, `_` separators dropped; the text when it overflows.
    static func integer(_ raw: String) -> StructuredValue {
        let plain = raw.replacingOccurrences(of: "_", with: "")
        let unsigned = plain.hasPrefix("+") ? String(plain.dropFirst()) : plain
        if let i = Int(unsigned) { return .integer(i) }
        if unsigned.hasPrefix("0x"), let i = Int(unsigned.dropFirst(2), radix: 16) { return .integer(i) }
        if unsigned.hasPrefix("0o"), let i = Int(unsigned.dropFirst(2), radix: 8) { return .integer(i) }
        if unsigned.hasPrefix("0b"), let i = Int(unsigned.dropFirst(2), radix: 2) { return .integer(i) }
        return .string(raw)
    }

    /// A TOML string's content: basic strings with their escapes resolved, literal strings as
    /// written, multi-line strings with the newline right after the opening delimiter dropped and
    /// (basic) a line-ending `\` trimming the whitespace that follows it.
    static func unquoted(_ raw: String) -> String {
        if raw.hasPrefix("\"\"\"") { return unescaped(stripFirstNewline(String(raw.dropFirst(3).dropLast(3))), multiline: true) }
        if raw.hasPrefix("'''") { return stripFirstNewline(String(raw.dropFirst(3).dropLast(3))) }
        if raw.hasPrefix("\"") { return unescaped(String(raw.dropFirst().dropLast()), multiline: false) }
        if raw.hasPrefix("'") { return String(raw.dropFirst().dropLast()) }
        return raw
    }

    private static func stripFirstNewline(_ s: String) -> String {
        if s.hasPrefix("\r\n") { return String(s.dropFirst(2)) }
        if s.hasPrefix("\n") { return String(s.dropFirst()) }
        return s
    }

    private static func unescaped(_ s: String, multiline: Bool) -> String {
        guard s.contains("\\") else { return s }
        var out = ""
        var chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            guard c == "\\", i + 1 < chars.count else { out.append(c); i += 1; continue }
            let e = chars[i + 1]
            i += 2
            switch e {
            case "b": out.append("\u{08}")
            case "t": out.append("\t")
            case "n": out.append("\n")
            case "f": out.append("\u{0C}")
            case "r": out.append("\r")
            case "e": out.append("\u{1B}")
            case "\"": out.append("\"")
            case "\\": out.append("\\")
            case "u", "U":
                let width = e == "u" ? 4 : 8
                let hex = String(chars[i..<min(chars.count, i + width)])
                i += hex.count
                if let v = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(v) { out.unicodeScalars.append(scalar) } else { out += "\\\(e)\(hex)" }
            case "\n", "\r\n", " ", "\t" where multiline:
                // A line-ending backslash: everything up to the next non-whitespace goes.
                var j = i - 1
                while j < chars.count, chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" || chars[j] == "\r\n" || chars[j] == "\r" { j += 1 }
                i = j
            default: out.append("\\"); out.append(e)
            }
        }
        chars = []
        return out
    }
}
