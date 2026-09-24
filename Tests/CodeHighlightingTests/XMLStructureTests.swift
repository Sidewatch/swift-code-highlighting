//
//  XMLStructureTests.swift
//  CodeHighlightingTests
//
//  An XML document as ordered structure — attributes, children, repeats, text, CDATA, entities — and its edit sites.
//
//  Created by David Sherlock on 9/25/26.
//

import XCTest
import DataConverter
@testable import CodeHighlighting

final class XMLStructureTests: XCTestCase {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <?xml-stylesheet type="text/xsl" href="catalog.xsl"?>
    <!DOCTYPE catalog [
      <!ENTITY publisher "O'Grady &amp; Sons">
    ]>
    <!-- a comment -->
    <catalog xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.1">
      <book id="bk101" available="true">
        <dc:title>The Emerald Vale</dc:title>
        <price currency="USD">29.95</price>
        <publisher>&publisher;</publisher>
        <blurb>Fewer than 5 &lt;copies&gt; left &#8212; order soon.</blurb>
        <review><![CDATA[Raw text: <not-a-tag> & unescaped.]]></review>
        <tags>
          <tag>fiction</tag>
          <!-- between -->
          <tag>fantasy</tag>
        </tags>
        <note>Read <em>this</em> first.</note>
        <cover href="covers/bk101.png"/>
        <empty></empty>
        <solo/>
      </book>
    </catalog>
    """
    func pairs(_ v: StructuredValue?) -> [StructuredPair] { if case .mapping(let p)? = v { return p } else { return [] } }
    func get(_ v: StructuredValue?, _ key: String) -> StructuredValue? { pairs(v).first { $0.key == key }?.value }
    func raw(_ r: NSRange?) -> String? { r.map { (xml as NSString).substring(with: $0) } }

    func testElementsAttributesChildrenAndText() throws {
        let root = try XCTUnwrap(XMLStructure.value(of: xml))
        XCTAssertEqual(pairs(root).map(\.key), ["catalog"], "the root element alone; prolog, DOCTYPE and comments are not values")
        let catalog = get(root, "catalog")
        XCTAssertEqual(pairs(catalog).map(\.key), ["@xmlns:dc", "@version", "book"], "attributes first, in file order, then children")
        XCTAssertEqual(get(catalog, "@version"), .string("2.1"))
        let book = get(catalog, "book")
        XCTAssertEqual(pairs(book).map(\.key), ["@id", "@available", "dc:title", "price", "publisher", "blurb", "review", "tags", "note", "cover", "empty", "solo"])
        XCTAssertEqual(get(book, "dc:title"), .string("The Emerald Vale"), "a leaf element is its text; the namespace prefix stays")
        XCTAssertEqual(pairs(get(book, "price")).map(\.key), ["@currency", "#text"], "attributes and text keep the text under #text")
        XCTAssertEqual(get(get(book, "price"), "#text"), .string("29.95"))
        XCTAssertEqual(get(book, "publisher"), .string("&publisher;"), "a DTD entity is left as written")
        XCTAssertEqual(get(book, "blurb"), .string("Fewer than 5 <copies> left — order soon."), "predefined and numeric references resolve")
        XCTAssertEqual(get(book, "review"), .string("Raw text: <not-a-tag> & unescaped."), "CDATA verbatim")
        XCTAssertEqual(get(get(book, "tags"), "tag"), .sequence([.string("fiction"), .string("fantasy")]), "a repeated child name is one sequence")
        XCTAssertEqual(pairs(get(book, "note")).map(\.key), ["em", "#text"], "mixed content: children, then the text")
        XCTAssertEqual(get(get(book, "note"), "#text"), .string("Read  first."))
        XCTAssertEqual(pairs(get(book, "cover")).map(\.key), ["@href"], "an empty element with attributes")
        XCTAssertEqual(get(book, "empty"), .string(""))
        XCTAssertNil(XMLStructure.value(of: "<!-- only -->"))
        XCTAssertEqual(XMLStructure.value(of: "<a/>"), .mapping([StructuredPair(key: "a", value: .string(""))]))
    }

    func testSitesAndReplacements() throws {
        let title = try XCTUnwrap(XMLStructure.site(in: xml, path: [.key("catalog"), .key("book"), .key("dc:title")]))
        XCTAssertEqual(raw(title.value), "The Emerald Vale"); XCTAssertNil(title.key, "an element's name is written twice: no key site")
        let version = try XCTUnwrap(XMLStructure.site(in: xml, path: [.key("catalog"), .key("@version")]))
        XCTAssertEqual(raw(version.value), "\"2.1\""); XCTAssertEqual(raw(version.key), "version")
        let second = try XCTUnwrap(XMLStructure.site(in: xml, path: [.key("catalog"), .key("book"), .key("tags"), .key("tag"), .index(1)]))
        XCTAssertEqual(raw(second.value), "fantasy")
        let price = try XCTUnwrap(XMLStructure.site(in: xml, path: [.key("catalog"), .key("book"), .key("price"), .key("#text")]))
        XCTAssertEqual(raw(price.value), "29.95", "the text of an element with attributes")
        let empty = try XCTUnwrap(XMLStructure.site(in: xml, path: [.key("catalog"), .key("book"), .key("empty")]))
        XCTAssertEqual(empty.value.length, 0, "an empty element's site is between its tags")
        XCTAssertNil(XMLStructure.site(in: xml, path: [.key("catalog"), .key("book"), .key("solo")]), "<solo/> has nowhere for text")
        let cover = try XCTUnwrap(XMLStructure.site(in: xml, path: [.key("catalog"), .key("book"), .key("cover")]))
        XCTAssertEqual(raw(cover.value), "<cover href=\"covers/bk101.png\"/>", "an element with attributes is a mapping whose span is the element")
        XCTAssertNil(XMLStructure.site(in: xml, path: [.key("catalog"), .key("nope")]))
        let href = try XCTUnwrap(XMLStructure.site(in: xml, path: [.key("catalog"), .key("book"), .key("cover"), .key("@href")]))
        XCTAssertEqual(raw(href.value), "\"covers/bk101.png\"")

        let retitled = (xml as NSString).replacingCharacters(in: title.value, with: XMLEdit.encodedText("Vale & <Dale>"))
        XCTAssertTrue(retitled.contains("<dc:title>Vale &amp; &lt;Dale&gt;</dc:title>"), retitled)
        let reversioned = (xml as NSString).replacingCharacters(in: version.value, with: XMLEdit.encodedAttribute("3.0"))
        XCTAssertTrue(reversioned.contains("version=\"3.0\">"), reversioned)
        let renamed = (xml as NSString).replacingCharacters(in: version.key!, with: XMLEdit.encodedAttributeName("@rev"))
        XCTAssertTrue(renamed.contains(" rev=\"2.1\">"), renamed)
    }

    func testIndentedTextKeepsItsIndentation() throws {
        let pretty = "<a>\n  <b>\n    hello\n  </b>\n</a>\n"
        let site = try XCTUnwrap(XMLStructure.site(in: pretty, path: [.key("a"), .key("b")]))
        XCTAssertEqual((pretty as NSString).substring(with: site.value), "hello")
        XCTAssertEqual((pretty as NSString).replacingCharacters(in: site.value, with: "bye"), "<a>\n  <b>\n    bye\n  </b>\n</a>\n")
    }
}
