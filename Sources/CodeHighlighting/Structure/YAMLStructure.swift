//
//  YAMLStructure.swift
//  CodeHighlighting
//
//  A YAML document as ordered structure — mappings, sequences, typed scalars — read off the
//  tree-sitter grammar vendored for highlighting, so a tree preview needs no second parser.
//
//  Created by David Sherlock on 9/22/26.
//

import Foundation
import SwiftTreeSitter
import CodeLanguage

/// A YAML document as ordered structure, from the vendored tree-sitter-yaml grammar.
///
/// Mappings keep the file's key order (a `[String: Any]` would not), scalars keep the type the
/// grammar gives them — `3` is an integer, `0.5` a number, `true` a boolean, an empty value or
/// `~` null, everything else a string with its quotes and escapes resolved — and a block scalar
/// (`|`, `>`) is its text with the indentation removed. Anchors and tags are dropped; an alias
/// stays as `*name`, unresolved, so the preview says what the file says.
///
/// Tree-sitter parses anything, so a malformed file yields whatever structure it can see, never
/// an error; ``value(of:)`` is nil only for an empty document or when the grammar is missing.
public enum YAMLStructure {

    /// One value of a document.
    public indirect enum Value: Equatable, Sendable {
        case mapping([Pair])
        case sequence([Value])
        case string(String)
        case integer(Int)
        case number(Double)
        case bool(Bool)
        case null
    }

    /// One `key: value` of a mapping, in file order.
    public struct Pair: Equatable, Sendable {
        public let key: String
        public let value: Value
        public init(key: String, value: Value) { self.key = key; self.value = value }
    }

    /// The FIRST document of `text`, or nil for an empty text (or no grammar).
    public static func value(of text: String) -> Value? { documents(in: text).first }

    /// Every document of `text` (`---` separates them), in order.
    public static func documents(in text: String) -> [Value] {
        guard let root = TreeSitterHighlighter.freshParseRoot(text, language: .yaml) else { return [] }
        let ns = text as NSString
        return namedChildren(root).filter { $0.nodeType == "document" }.compactMap { doc in
            guard let body = namedChildren(doc).first(where: { ["block_node", "flow_node"].contains($0.nodeType ?? "") }) else { return nil }
            return convert(body, ns: ns)
        }
    }

    // MARK: - Walking

    static func namedChildren(_ node: Node) -> [Node] {
        (0..<node.namedChildCount).compactMap { node.namedChild(at: $0) }
    }

    static func text(_ node: Node, _ ns: NSString) -> String {
        NSMaxRange(node.range) <= ns.length ? ns.substring(with: node.range) : ""
    }

    /// The node's content: a `block_node` / `flow_node` unwraps to the collection or scalar inside
    /// it (past any anchor, tag or comment).
    static func convert(_ node: Node, ns: NSString) -> Value {
        switch node.nodeType ?? "" {
        case "block_node", "flow_node":
            guard let inner = namedChildren(node).first(where: { !["anchor", "tag", "comment"].contains($0.nodeType ?? "") }) else { return .null }
            return convert(inner, ns: ns)
        case "block_mapping", "flow_mapping":
            let pairs = namedChildren(node).filter { ["block_mapping_pair", "flow_pair"].contains($0.nodeType ?? "") }.map { pair -> Pair in
                let key = pair.child(byFieldName: "key").map { keyText(convert($0, ns: ns)) } ?? ""
                let value = pair.child(byFieldName: "value").map { convert($0, ns: ns) } ?? .null
                return Pair(key: key, value: value)
            }
            return .mapping(pairs)
        case "block_sequence":
            return .sequence(namedChildren(node).filter { $0.nodeType == "block_sequence_item" }.map { item in
                namedChildren(item).first(where: { $0.nodeType != "comment" }).map { convert($0, ns: ns) } ?? .null
            })
        case "flow_sequence":
            return .sequence(namedChildren(node).filter { $0.nodeType != "comment" }.map { convert($0, ns: ns) })
        case "flow_pair":   // a single `key: value` inside a flow sequence
            let key = node.child(byFieldName: "key").map { keyText(convert($0, ns: ns)) } ?? ""
            return .mapping([Pair(key: key, value: node.child(byFieldName: "value").map { convert($0, ns: ns) } ?? .null)])
        case "plain_scalar":
            guard let inner = namedChildren(node).first else { return .string(text(node, ns)) }
            return convert(inner, ns: ns)
        case "string_scalar": return .string(text(node, ns))
        case "integer_scalar":
            let raw = text(node, ns).replacingOccurrences(of: "_", with: "")
            if let i = Int(raw) { return .integer(i) }
            if raw.hasPrefix("0x"), let i = Int(raw.dropFirst(2), radix: 16) { return .integer(i) }
            if raw.hasPrefix("0o"), let i = Int(raw.dropFirst(2), radix: 8) { return .integer(i) }
            return .string(text(node, ns))
        case "float_scalar":
            return Double(text(node, ns).replacingOccurrences(of: "_", with: "")).map { .number($0) } ?? .string(text(node, ns))
        case "boolean_scalar": return .bool(["true", "True", "TRUE", "yes", "Yes", "YES", "on", "On", "ON"].contains(text(node, ns)))
        case "null_scalar": return .null
        case "double_quote_scalar": return .string(unescapeDouble(String(text(node, ns).dropFirst().dropLast())))
        case "single_quote_scalar": return .string(String(text(node, ns).dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'"))
        case "block_scalar": return .string(blockScalar(text(node, ns)))
        case "alias": return .string(text(node, ns))
        default: return .string(text(node, ns))
        }
    }

    /// A key as the string the file wrote: `1:` is the key "1".
    static func keyText(_ value: Value) -> String {
        switch value {
        case .string(let s): return s
        case .integer(let i): return String(i)
        case .number(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        case .mapping, .sequence: return "?"
        }
    }

    /// YAML's double-quoted escapes: `\n`, `\t`, `\"`, `\\`, `\/`, `\xHH`, `\uHHHH`.
    private static func unescapeDouble(_ s: String) -> String {
        guard s.contains("\\") else { return s }
        var out = ""
        var chars = s.makeIterator()
        while let c = chars.next() {
            guard c == "\\", let e = chars.next() else { out.append(c); continue }
            switch e {
            case "n": out.append("\n")
            case "t": out.append("\t")
            case "r": out.append("\r")
            case "0": out.append("\0")
            case "x", "u", "U":
                let width = e == "x" ? 2 : (e == "u" ? 4 : 8)
                var hex = ""
                for _ in 0..<width { if let h = chars.next() { hex.append(h) } }
                if let v = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(v) { out.unicodeScalars.append(scalar) } else { out += "\\\(e)\(hex)" }
            default: out.append(e)   // \" \\ \/ and anything unknown: the character itself
            }
        }
        return out
    }

    /// A `|` or `>` block scalar: the lines after the header, dedented by the shallowest
    /// indentation; a folded (`>`) block joins its lines with spaces. `-` keeps no final newline.
    private static func blockScalar(_ raw: String) -> String {
        var lines = raw.components(separatedBy: "\n")
        let header = lines.removeFirst().trimmingCharacters(in: .whitespaces)
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        let indent = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.prefix { $0 == " " }.count }.min() ?? 0
        let body = lines.map { String($0.dropFirst(min(indent, $0.prefix { $0 == " " }.count))) }
        let joined = header.hasPrefix(">") ? body.joined(separator: " ") : body.joined(separator: "\n")
        return header.hasSuffix("-") ? joined : joined + "\n"
    }
}
