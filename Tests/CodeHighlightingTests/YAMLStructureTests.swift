//
//  YAMLStructureTests.swift
//  CodeHighlightingTests
//
//  A YAML document read as ordered structure off the vendored grammar: key order kept, scalars
//  typed, quotes and block scalars resolved, flow collections, several documents.
//
//  Created by David Sherlock on 9/22/26.
//

import XCTest
@testable import CodeHighlighting

/// Tests for `YAMLStructure`.
final class YAMLStructureTests: XCTestCase {
    typealias V = YAMLStructure.Value
    typealias P = YAMLStructure.Pair

    private let compose = """
    # a service file
    version: "3.9"
    services:
      web:
        image: nginx:1.25
        ports:
          - "80:80"
          - 443
        debug: true
        replicas: 3
        ratio: 0.5
        empty:
        nothing: ~
        notes: |
          line one
          line two
      db: {image: postgres, env: [A, 'it''s', "q\\"x"]}
    list: [1, two, 3.5]
    """

    private func mapping(_ v: V?) -> [P]? { if case .mapping(let p)? = v { return p }; return nil }
    private func get(_ v: V?, _ key: String) -> V? { mapping(v)?.first { $0.key == key }?.value }

    func testMappingsKeepFileOrderAndScalarsAreTyped() throws {
        let root = try XCTUnwrap(YAMLStructure.value(of: compose))
        XCTAssertEqual(mapping(root)?.map(\.key), ["version", "services", "list"], "the file's order, not alphabetical")
        XCTAssertEqual(get(root, "version"), .string("3.9"), "a quoted number is a string")
        let web = get(get(root, "services"), "web")
        XCTAssertEqual(mapping(web)?.map(\.key), ["image", "ports", "debug", "replicas", "ratio", "empty", "nothing", "notes"])
        XCTAssertEqual(get(web, "image"), .string("nginx:1.25"))
        XCTAssertEqual(get(web, "ports"), .sequence([.string("80:80"), .integer(443)]))
        XCTAssertEqual(get(web, "debug"), .bool(true))
        XCTAssertEqual(get(web, "replicas"), .integer(3))
        XCTAssertEqual(get(web, "ratio"), .number(0.5))
        XCTAssertEqual(get(web, "empty"), .null, "a key with nothing after it")
        XCTAssertEqual(get(web, "nothing"), .null)
        XCTAssertEqual(get(web, "notes"), .string("line one\nline two\n"), "a literal block scalar, dedented")
    }

    func testFlowCollectionsAndQuotedScalars() throws {
        let root = try XCTUnwrap(YAMLStructure.value(of: compose))
        let db = get(get(root, "services"), "db")
        XCTAssertEqual(get(db, "image"), .string("postgres"))
        XCTAssertEqual(get(db, "env"), .sequence([.string("A"), .string("it's"), .string("q\"x")]), "single-quote doubling and double-quote escapes resolve")
        XCTAssertEqual(get(root, "list"), .sequence([.integer(1), .string("two"), .number(3.5)]))
    }

    func testFoldedBlocksKeepMarkersAndHexIntegers() {
        let v = YAMLStructure.value(of: "a: >-\n  one\n  two\nb: 0x1F\nc: 1_000\nd: \"tab\\there\"\n")
        XCTAssertEqual(get(v, "a"), .string("one two"))
        XCTAssertEqual(get(v, "b"), .integer(31))
        XCTAssertEqual(get(v, "c"), .string("1_000"), "YAML 1.2 has no digit separators: the grammar reads it as a string")
        XCTAssertEqual(get(v, "d"), .string("tab\there"))
    }

    func testSeveralDocumentsASequenceRootAndAnEmptyText() {
        let docs = YAMLStructure.documents(in: "---\na: 1\n---\n- x\n- y\n")
        XCTAssertEqual(docs.count, 2)
        XCTAssertEqual(docs.first, .mapping([P(key: "a", value: .integer(1))]))
        XCTAssertEqual(docs.last, .sequence([.string("x"), .string("y")]))
        XCTAssertEqual(YAMLStructure.value(of: "- 1\n- 2"), .sequence([.integer(1), .integer(2)]), "a document can be a list")
        XCTAssertNil(YAMLStructure.value(of: ""))
        XCTAssertNil(YAMLStructure.value(of: "# only a comment\n"))
    }

    func testAnAliasStaysUnresolvedAndAnAnchorIsDropped() {
        let v = YAMLStructure.value(of: "base: &b\n  x: 1\nother: *b\n")
        XCTAssertEqual(get(v, "base"), .mapping([P(key: "x", value: .integer(1))]))
        XCTAssertEqual(get(v, "other"), .string("*b"))
    }
}
