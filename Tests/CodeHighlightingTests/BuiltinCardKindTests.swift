//
//  BuiltinCardKindTests.swift
//  CodeHighlightingTests
//
//  What a built-in's hover card calls it, read off the signature line alone.
//

import XCTest
@testable import CodeHighlighting

final class BuiltinCardKindTests: XCTestCase {

    private func kind(_ word: String, _ signature: String) -> SymbolKind {
        LanguageBuiltins.cardKind(word: word, signature: signature).kind
    }

    func testDeclarationOpenersDecide() {
        XCTAssertEqual(kind("os", "module os — operating system interfaces"), .module)
        XCTAssertEqual(kind("Map", "class Map<K, V>"), .type)
        XCTAssertEqual(kind("Sendable", "marker trait Sendable"), .type)
        XCTAssertEqual(kind("length", "var length: Int"), .property)
        XCTAssertEqual(LanguageBuiltins.cardKind(word: "os", signature: "module os").doc, "Built-in module")
    }

    func testADescribedNameIsATypeWhenCapitalisedOrQualified() {
        XCTAssertEqual(kind("Map", "Map<K, V> — keyed collection"), .type)
        XCTAssertEqual(kind("Mutex", "sync.Mutex — mutual exclusion lock"), .type)
        XCTAssertEqual(kind("vector", "std::vector<T> — dynamic array"), .type)
        XCTAssertEqual(kind("errno", "errno — the last error number"), .constant)
        XCTAssertEqual(kind("other", "errno — the last error number"), .constant, "not this word: falls through to the value rule")
    }

    func testCallsAndValues() {
        XCTAssertEqual(kind("array_map", "array_map(callable $callback, array $array): array"), .function)
        XCTAssertEqual(kind("localStorage", "localStorage: Storage — getItem(key), setItem(key, value)"), .property)
        XCTAssertEqual(kind("PI", "PI: number = 3.14"), .property)
        XCTAssertEqual(kind("true", "true"), .constant)
    }
}
