//
//  TOMLStructureTests.swift
//  CodeHighlightingTests
//
//  A TOML document as ordered structure, and the site of any key or value in it.
//
//  Created by David Sherlock on 9/25/26.
//

import XCTest
import DataConverter
@testable import CodeHighlighting

final class TOMLStructureTests: XCTestCase {
    let toml = """
    # a service
    title = "Sidewatch \\"Service\\"\\tConfig"
    enabled = true
    max = 1_000
    hex = 0xDEADBEEF
    oct = 0o755
    bin = 0b1010
    neg = -17
    ratio = 30.5
    big = 1.5e3
    inf = +inf
    when = 1979-05-27T07:32:00Z
    day = 1979-05-27
    ports = [8080, 8443, 9090]
    hosts = ["alpha", 'b"c', ]
    nested = [[1, 2], ["a"]]
    point = { x = 1, y = "two" }
    site."google.com" = 42
    path = 'C:\\Users\\app'
    bio = \"\"\"
    Multi-line \\
        joined.
    Second.
    \"\"\"
    lit = '''
    raw \\n stays
    '''

    [database]
    server = "192.168.1.1"
    port = 5432

    [servers]

      [servers.primary]
      ip = "10.0.0.1"

      [servers.replica]
      ip = "10.0.0.2"

    [[products]]
    name = "Hammer"
    sku = 738594937

    [[products]]
    name = "Nail"
    color = "gray"

    [owner]
    name = "David"
    dob.year = 1990
    dob.month = 1
    """
    typealias V = StructuredValue
    func pairs(_ v: V?) -> [StructuredPair] { if case .mapping(let p)? = v { return p } else { return [] } }
    func get(_ v: V?, _ key: String) -> V? { pairs(v).first { $0.key == key }?.value }
    func raw(_ r: NSRange?) -> String? { r.map { (toml as NSString).substring(with: $0) } }

    func testEveryValueKindAndTablesInFileOrder() throws {
        let root = try XCTUnwrap(TOMLStructure.value(of: toml))
        XCTAssertEqual(pairs(root).map(\.key), ["title", "enabled", "max", "hex", "oct", "bin", "neg", "ratio", "big", "inf", "when", "day", "ports", "hosts", "nested", "point", "site", "path", "bio", "lit", "database", "servers", "products", "owner"], "pairs, then tables, in the file's order")
        XCTAssertEqual(get(root, "title"), .string("Sidewatch \"Service\"\tConfig"), "basic-string escapes resolve")
        XCTAssertEqual(get(root, "enabled"), .bool(true))
        XCTAssertEqual(get(root, "max"), .integer(1000), "underscores drop")
        XCTAssertEqual(get(root, "hex"), .integer(0xDEADBEEF))
        XCTAssertEqual(get(root, "oct"), .integer(0o755))
        XCTAssertEqual(get(root, "bin"), .integer(10))
        XCTAssertEqual(get(root, "neg"), .integer(-17))
        XCTAssertEqual(get(root, "ratio"), .number(30.5))
        XCTAssertEqual(get(root, "big"), .number(1500))
        XCTAssertEqual(get(root, "inf"), .string("+inf"), "inf and nan stay text")
        XCTAssertEqual(get(root, "when"), .string("1979-05-27T07:32:00Z"), "a date-time is its text")
        XCTAssertEqual(get(root, "day"), .string("1979-05-27"))
        XCTAssertEqual(get(root, "ports"), .sequence([.integer(8080), .integer(8443), .integer(9090)]))
        XCTAssertEqual(get(root, "hosts"), .sequence([.string("alpha"), .string("b\"c")]), "a trailing comma adds nothing; a literal string is raw")
        XCTAssertEqual(get(root, "nested"), .sequence([.sequence([.integer(1), .integer(2)]), .sequence([.string("a")])]))
        XCTAssertEqual(pairs(get(root, "point")).map(\.key), ["x", "y"], "an inline table is a mapping")
        XCTAssertEqual(get(get(root, "site"), "google.com"), .integer(42), "a dotted key with a quoted segment nests")
        XCTAssertEqual(get(root, "path"), .string("C:\\Users\\app"))
        XCTAssertEqual(get(root, "bio"), .string("Multi-line joined.\nSecond.\n"), "the first newline goes; a line-ending backslash joins")
        XCTAssertEqual(get(root, "lit"), .string("raw \\n stays\n"))
        let db = get(root, "database")
        XCTAssertEqual(pairs(db).map(\.key), ["server", "port"])
        XCTAssertEqual(get(db, "port"), .integer(5432))
        let servers = get(root, "servers")
        XCTAssertEqual(pairs(servers).map(\.key), ["primary", "replica"], "[servers.primary] nests under [servers]")
        XCTAssertEqual(get(get(servers, "replica"), "ip"), .string("10.0.0.2"))
        guard case .sequence(let products)? = get(root, "products") else { return XCTFail("[[products]] is a sequence") }
        XCTAssertEqual(products.count, 2)
        XCTAssertEqual(pairs(products[1]).map(\.key), ["name", "color"])
        let owner = get(root, "owner")
        XCTAssertEqual(pairs(get(owner, "dob")).map(\.key), ["year", "month"], "dotted keys under a table nest")
        XCTAssertNil(TOMLStructure.value(of: "# nothing\n"))
    }

    func testSitesAndReplacements() throws {
        let port = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("database"), .key("port")]))
        XCTAssertEqual(raw(port.key), "port"); XCTAssertEqual(raw(port.value), "5432")
        let title = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("title")]))
        XCTAssertEqual(raw(title.value), "\"Sidewatch \\\"Service\\\"\\tConfig\"", "a string's site includes its quotes")
        let second = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("ports"), .index(1)]))
        XCTAssertEqual(raw(second.value), "8443"); XCTAssertNil(second.key)
        let deep = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("nested"), .index(0), .index(1)]))
        XCTAssertEqual(raw(deep.value), "2")
        let inline = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("point"), .key("y")]))
        XCTAssertEqual(raw(inline.value), "\"two\""); XCTAssertEqual(raw(inline.key), "y")
        let quoted = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("site"), .key("google.com")]))
        XCTAssertEqual(raw(quoted.key), "\"google.com\"", "the last segment of a dotted key")
        let replica = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("servers"), .key("replica")]))
        XCTAssertEqual(raw(replica.key), "replica", "a table header's last segment")
        let product = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("products"), .index(1), .key("name")]))
        XCTAssertEqual(raw(product.value), "\"Nail\"")
        let year = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("owner"), .key("dob"), .key("year")]))
        XCTAssertEqual(raw(year.value), "1990"); XCTAssertEqual(raw(year.key), "year")
        let bio = try XCTUnwrap(TOMLStructure.site(in: toml, path: [.key("bio")]))
        XCTAssertTrue(raw(bio.value)!.hasPrefix("\"\"\"\nMulti-line"))
        XCTAssertNil(TOMLStructure.site(in: toml, path: [.key("nope")]))
        XCTAssertNil(TOMLStructure.site(in: toml, path: [.key("ports"), .index(9)]))
        XCTAssertNil(TOMLStructure.site(in: toml, path: [.key("database"), .index(0)]))

        let out = (toml as NSString).replacingCharacters(in: port.value, with: TOMLEdit.encodedScalar("5433", kind: .number))
        XCTAssertTrue(out.contains("port = 5433\n"), out)
        let renamed = (toml as NSString).replacingCharacters(in: replica.key!, with: TOMLEdit.encodedKey("standby"))
        XCTAssertTrue(renamed.contains("[servers.standby]\n"), renamed)
    }
}
