//
//  YAMLEditSiteTests.swift
//  CodeHighlightingTests
//
//  The site of a key or value by path in a YAML file, and how a typed replacement is written.
//
//  Created by David Sherlock on 9/25/26.
//

import XCTest
@testable import CodeHighlighting

final class YAMLEditSiteTests: XCTestCase {
    let text = """
    version: "3.9"
    services:
      web:
        image: nginx   # the front door
        ports: [80, 443]
      db:
        image: postgres
    list:
      - a
      - "b c"
    script: |
      echo one
      echo two
    empty:
    """
    func raw(_ r: NSRange?) -> String? { r.map { (text as NSString).substring(with: $0) } }

    func testFindsKeysAndValuesByPath() throws {
        let image = try XCTUnwrap(YAMLStructure.site(in: text, path: [.key("services"), .key("web"), .key("image")]))
        XCTAssertEqual(raw(image.value), "nginx"); XCTAssertEqual(raw(image.key), "image")
        let version = try XCTUnwrap(YAMLStructure.site(in: text, path: [.key("version")]))
        XCTAssertEqual(raw(version.value), "\"3.9\"", "a quoted scalar's range includes its quotes")
        let port = try XCTUnwrap(YAMLStructure.site(in: text, path: [.key("services"), .key("web"), .key("ports"), .index(1)]))
        XCTAssertEqual(raw(port.value), "443"); XCTAssertNil(port.key)
        let second = try XCTUnwrap(YAMLStructure.site(in: text, path: [.key("list"), .index(1)]))
        XCTAssertEqual(raw(second.value), "\"b c\"")
        let script = try XCTUnwrap(YAMLStructure.site(in: text, path: [.key("script")]))
        XCTAssertTrue(raw(script.value)!.hasPrefix("|\n  echo one"), raw(script.value)!)
        let container = try XCTUnwrap(YAMLStructure.site(in: text, path: [.key("services"), .key("db")]))
        XCTAssertEqual(raw(container.key), "db"); XCTAssertTrue(raw(container.value)!.hasPrefix("image: postgres"))
        let empty = try XCTUnwrap(YAMLStructure.site(in: text, path: [.key("empty")]))
        XCTAssertEqual(empty.value.length, 0, "a key with no value has an empty site right after it")
        XCTAssertNil(YAMLStructure.site(in: text, path: [.key("nope")]))
        XCTAssertNil(YAMLStructure.site(in: text, path: [.key("list"), .index(5)]))
    }

    func testReplacingThroughTheSiteLeavesTheRestAsWritten() throws {
        let site = try XCTUnwrap(YAMLStructure.site(in: text, path: [.key("services"), .key("web"), .key("image")]))
        let out = (text as NSString).replacingCharacters(in: site.value, with: "\"caddy: latest\"")
        XCTAssertTrue(out.contains("    image: \"caddy: latest\"   # the front door"), out)
        let renamed = (text as NSString).replacingCharacters(in: site.key!, with: "container")
        XCTAssertTrue(renamed.contains("    container: nginx"), renamed)
    }
}
