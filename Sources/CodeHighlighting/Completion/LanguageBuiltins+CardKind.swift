//
//  LanguageBuiltins+CardKind.swift
//  CodeHighlighting
//
//  What a built-in's hover card should call it, read off its signature: `module …` for modules,
//  `var …` for properties, `Name — …` for a type or namespace described rather than called,
//  `name: Type` for a value; anything else with a `(` is a call.
//
//  Created by David Sherlock on 9/5/26.
//

import Foundation

extension LanguageBuiltins {

    /// What a built-in's hover card should call it, read off its signature: `module …` for
    /// modules, `var …` for properties, `Name — …` for a type or namespace described rather
    /// than called, `name: Type` for a value; anything else with a `(` is a call. Before
    /// 4 Sep 2026 every builtin said "Built-in function", which read wrong on `Map` or `os`.
    public static func cardKind(word: String, signature: String) -> (kind: SymbolKind, doc: String) {
        let s = signature
        if s.hasPrefix("module ") || s.hasPrefix("package ") { return (.module, "Built-in module") }
        if typePrefixes.contains(where: { s.hasPrefix($0) }) { return (.type, "Built-in type") }
        if s.hasPrefix("var ") || s.hasPrefix("let ") { return (.property, "Built-in property") }
        if let described = describedNameKind(word: word, signature: s) { return described }
        if let paren = s.firstIndex(of: "(") {
            // `localStorage: Storage — getItem(key)…` — a value whose description mentions calls
            if let colon = s.firstIndex(of: ":"), colon < paren, s[..<colon].hasSuffix(word) {
                return (.property, "Built-in property")
            }
            return (.function, "Built-in function")
        }
        if s.contains(":") { return (.property, "Built-in property") }   // `PI: number = 3.14`
        return (.constant, "Built-in value")
    }

    /// Signature openers that declare a type.
    private static let typePrefixes = ["class ", "struct ", "enum ", "protocol ", "typealias ", "interface ", "trait ",
                                       "type ", "typing.", "@globalActor", "marker trait ", "open class ", "data class ",
                                       "object ", "static class ", "delegate ", "new "]

    /// `Name — …`, `Map<K, V> — …`, `std::vector<T> — …`, `sync.Mutex — …`, `errno — …`: a name
    /// described rather than called. A type when capitalised or qualified, else a value. Nil
    /// when the head is not a bare description of `word`.
    private static func describedNameKind(word: String, signature s: String) -> (kind: SymbolKind, doc: String)? {
        guard let dash = s.range(of: " — ") else { return nil }
        let head = s[..<dash.lowerBound]
        guard !head.contains("(") && !head.contains(":") || head.contains("::") else { return nil }
        let generic = head.split(separator: "<").first.map(String.init) ?? String(head)
        let bare = generic.split(whereSeparator: { $0 == "." || $0 == ":" }).last.map(String.init) ?? generic
        guard bare == word else { return nil }
        let qualified = generic.contains(".") || generic.contains("::")
        if word.first?.isUppercase == true || qualified { return (.type, "Built-in type") }
        return (.constant, "Built-in value")
    }
}
