//
//  PlistStructureTests.swift
//  CodeHighlightingTests
//
//  An XML property list in file order with edit sites; a binary one read through Foundation.
//
//  Created by David Sherlock on 9/25/26.
//

import XCTest
import DataConverter
@testable import CodeHighlighting

final class PlistStructureTests: XCTestCase {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    	<!-- the bundle -->
    	<key>CFBundleName</key>
    	<string>Inventory &amp; Co</string>
    	<key>CFBundleVersion</key>
    	<integer>42</integer>
    	<key>Ratio</key>
    	<real>0.5</real>
    	<key>Sandboxed</key>
    	<true/>
    	<key>Debug</key>
    	<false/>
    	<key>Built</key>
    	<date>2026-09-25T10:00:00Z</date>
    	<key>Blob</key>
    	<data>
    	AQID
    	</data>
    	<key>Groups</key>
    	<array>
    		<string>$(AppIdentifierPrefix)com.example</string>
    		<string></string>
    	</array>
    	<key>Nested</key>
    	<dict>
    		<key>z</key>
    		<integer>1</integer>
    		<key>a</key>
    		<integer>2</integer>
    	</dict>
    </dict>
    </plist>
    """
    func pairs(_ v: StructuredValue?) -> [StructuredPair] { if case .mapping(let p)? = v { return p } else { return [] } }
    func get(_ v: StructuredValue?, _ key: String) -> StructuredValue? { pairs(v).first { $0.key == key }?.value }
    func raw(_ r: NSRange?) -> String? { r.map { (plist as NSString).substring(with: $0) } }

    func testXMLPlistKeepsOrderAndTypes() throws {
        let root = try XCTUnwrap(PlistStructure.value(of: plist))
        XCTAssertEqual(pairs(root).map(\.key), ["CFBundleName", "CFBundleVersion", "Ratio", "Sandboxed", "Debug", "Built", "Blob", "Groups", "Nested"], "the file's order, the wrapper gone")
        XCTAssertEqual(get(root, "CFBundleName"), .string("Inventory & Co"))
        XCTAssertEqual(get(root, "CFBundleVersion"), .integer(42))
        XCTAssertEqual(get(root, "Ratio"), .number(0.5))
        XCTAssertEqual(get(root, "Sandboxed"), .bool(true))
        XCTAssertEqual(get(root, "Debug"), .bool(false))
        XCTAssertEqual(get(root, "Built"), .string("2026-09-25T10:00:00Z"))
        XCTAssertEqual(get(root, "Blob"), .string("AQID"), "data without its whitespace")
        XCTAssertEqual(get(root, "Groups"), .sequence([.string("$(AppIdentifierPrefix)com.example"), .string("")]))
        XCTAssertEqual(pairs(get(root, "Nested")).map(\.key), ["z", "a"], "not sorted")
        XCTAssertEqual(PlistStructure.value(of: "<array><integer>1</integer></array>"), .sequence([.integer(1)]), "a bare root is taken as is")
        XCTAssertNil(PlistStructure.value(of: "<catalog><book/></catalog>"), "not a plist")
    }

    func testSitesAndReplacements() throws {
        let version = try XCTUnwrap(PlistStructure.site(in: plist, path: [.key("CFBundleVersion")]))
        XCTAssertEqual(raw(version.key), "CFBundleVersion"); XCTAssertEqual(raw(version.value), "42")
        let sandboxed = try XCTUnwrap(PlistStructure.site(in: plist, path: [.key("Sandboxed")]))
        XCTAssertEqual(raw(sandboxed.value), "<true/>", "a boolean's site is its element")
        let group = try XCTUnwrap(PlistStructure.site(in: plist, path: [.key("Groups"), .index(0)]))
        XCTAssertEqual(raw(group.value), "$(AppIdentifierPrefix)com.example"); XCTAssertNil(group.key)
        let blank = try XCTUnwrap(PlistStructure.site(in: plist, path: [.key("Groups"), .index(1)]))
        XCTAssertEqual(blank.value.length, 0)
        let nested = try XCTUnwrap(PlistStructure.site(in: plist, path: [.key("Nested"), .key("a")]))
        XCTAssertEqual(raw(nested.value), "2"); XCTAssertEqual(raw(nested.key), "a")
        XCTAssertNil(PlistStructure.site(in: plist, path: [.key("Nope")]))

        let bumped = (plist as NSString).replacingCharacters(in: version.value, with: PlistEdit.encodedScalar("43", kind: .number))
        XCTAssertTrue(bumped.contains("<integer>43</integer>"), bumped)
        let flipped = (plist as NSString).replacingCharacters(in: sandboxed.value, with: PlistEdit.encodedScalar("false", kind: .bool))
        XCTAssertTrue(flipped.contains("<key>Sandboxed</key>\n\t<false/>"), flipped)
        let worded = (plist as NSString).replacingCharacters(in: sandboxed.value, with: PlistEdit.encodedScalar("maybe", kind: .bool))
        XCTAssertTrue(worded.contains("<key>Sandboxed</key>\n\t<string>maybe</string>"), worded)
        let renamed = (plist as NSString).replacingCharacters(in: nested.key!, with: PlistEdit.encodedKey("b<c"))
        XCTAssertTrue(renamed.contains("<key>b&lt;c</key>"), renamed)
    }

    func testBinaryPlistReadsThroughFoundationWithoutSites() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["z": 1, "a": ["x", true]], format: .binary, options: 0)
        XCTAssertEqual(PlistStructure.value(of: data), .mapping([StructuredPair(key: "a", value: .sequence([.string("x"), .bool(true)])), StructuredPair(key: "z", value: .integer(1))]))
        let latin = String(data: data, encoding: .isoLatin1)!
        XCTAssertEqual(PlistStructure.value(of: latin), PlistStructure.value(of: data), "a binary plist opened as Latin-1 text reads the same")
        XCTAssertNil(PlistStructure.site(in: latin, path: [.key("z")]), "nothing to write into")
    }
}
