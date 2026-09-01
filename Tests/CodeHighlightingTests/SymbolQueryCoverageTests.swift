//
//  SymbolQueryCoverageTests.swift
//  CodeHighlightingTests
//
//  The symbol queries added for grammars that were vendored without one: Bash,
//  Kotlin, Dart, Scala, SQL. Each test pins the names, kinds and lines a small
//  real-shaped file yields, and the nesting the shared tree builder derives —
//  a query that compiles but matches nothing would otherwise pass silently
//  (`symbols(in:)` returns [] for a query that fails to compile).
//

import XCTest
import CodeLanguage
@testable import CodeHighlighting

final class SymbolQueryCoverageTests: XCTestCase {

    private func names(_ syms: [Symbol]) -> [String] { syms.map(\.name) }

    func testBashFunctions() throws {
        try XCTSkipUnless(TreeSitterHighlighter.supports(.bash))
        let sh = """
        #!/bin/bash
        deploy() {
          echo hi
        }
        function cleanup {
          rm -f x
        }
        """
        let syms = TreeSitterHighlighter.symbols(in: sh, language: .bash)
        XCTAssertEqual(names(syms), ["deploy", "cleanup"])
        XCTAssertEqual(syms.map(\.kind), [.function, .function])
        XCTAssertEqual(syms.map(\.line), [2, 5])
    }

    func testKotlinDeclarations() throws {
        try XCTSkipUnless(TreeSitterHighlighter.supports(.kotlin))
        let kt = """
        interface Shape { fun area(): Double }
        data class Circle(val r: Double) : Shape {
            val cached: Int = 1
            override fun area(): Double = 3.14 * r * r
        }
        object Registry
        typealias Id = String
        val limit = 10
        fun main() {}
        """
        let syms = TreeSitterHighlighter.symbols(in: kt, language: .kotlin)
        XCTAssertEqual(names(syms), ["Shape", "area", "Circle", "cached", "area", "Registry", "Id", "limit", "main"])
        XCTAssertEqual(syms.map(\.kind), [.interface, .function, .type, .property, .function, .type, .type, .property, .function])
        let tree = OutlineTree.build(from: syms)
        XCTAssertEqual(tree.map(\.symbol.name), ["Shape", "Circle", "Registry", "Id", "limit", "main"])
        // `dropFirst().first`, not `tree[1]`: a failing query yields an empty tree, and a
        // failed assertion must not become a crash that hides the whole run's summary.
        XCTAssertEqual(tree.dropFirst().first?.children.map(\.symbol.name), ["cached", "area"], "members nest under their class")
    }

    func testDartDeclarations() throws {
        try XCTSkipUnless(TreeSitterHighlighter.supports(.dart))
        let dart = """
        class Box {
          int size = 1;
          int get area => size * size;
          void render() {}
        }
        enum Color { red, green }
        mixin Loggable {}
        extension BoxExt on Box {}
        void main() {}
        """
        let syms = TreeSitterHighlighter.symbols(in: dart, language: .dart)
        XCTAssertEqual(names(syms), ["Box", "area", "render", "Color", "Loggable", "BoxExt", "main"])
        XCTAssertEqual(syms.map(\.kind), [.type, .property, .function, .enumeration, .type, .type, .function])
        let tree = OutlineTree.build(from: syms)
        XCTAssertEqual(tree.first?.children.map(\.symbol.name), ["area", "render"], "members nest under their class")
    }

    func testScalaDefinitions() throws {
        try XCTSkipUnless(TreeSitterHighlighter.supports(.scala))
        let scala = """
        trait Shape { def area: Double }
        class Circle(r: Double) extends Shape {
          val cached = 1
          def area: Double = 3.14 * r * r
        }
        object Registry
        enum Color { case Red, Green }
        def helper(x: Int): Int = x
        """
        let syms = TreeSitterHighlighter.symbols(in: scala, language: .scala)
        XCTAssertEqual(names(syms), ["Shape", "area", "Circle", "cached", "area", "Registry", "Color", "helper"])
        XCTAssertEqual(syms.map(\.kind), [.interface, .function, .type, .constant, .function, .type, .enumeration, .function])
        let tree = OutlineTree.build(from: syms)
        XCTAssertEqual(tree.map(\.symbol.name), ["Shape", "Circle", "Registry", "Color", "helper"])
    }

    func testSQLCreateStatements() throws {
        try XCTSkipUnless(TreeSitterHighlighter.supports(.sql))
        let sql = """
        CREATE TABLE users (id INT);
        CREATE VIEW active_users AS SELECT * FROM users;
        CREATE FUNCTION add_one(x INT) RETURNS INT AS $$ SELECT x + 1 $$ LANGUAGE SQL;
        CREATE TYPE mood AS ENUM ('sad', 'ok');
        CREATE SCHEMA app;
        """
        let syms = TreeSitterHighlighter.symbols(in: sql, language: .sql)
        XCTAssertEqual(names(syms), ["users", "active_users", "add_one", "mood", "app"])
        XCTAssertEqual(syms.map(\.kind), [.type, .type, .function, .type, .module])
        XCTAssertEqual(syms.map(\.line), [1, 2, 3, 4, 5])
    }

    /// The same table drives cross-file lookups, so a new query language sees itself
    /// (and only itself) in the project index.
    func testNewLanguagesAreVisibleToThemselves() {
        for lang: Language in [.bash, .kotlin, .dart, .scala, .sql] {
            XCTAssertEqual(SymbolQueries.visibleLanguages(from: lang), [lang], "\(lang)")
        }
    }
}
