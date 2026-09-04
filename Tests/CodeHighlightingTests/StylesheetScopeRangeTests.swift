//
//  StylesheetScopeRangeTests.swift
//  CodeHighlightingTests
//
//  The exact extent of an at-rule's scope: it must run through its closing brace,
//  so a caret ON the brace still reads as inside the block.
//

import XCTest
@testable import CodeHighlighting

final class StylesheetScopeRangeTests: XCTestCase {

    func testAtRuleScopeRunsThroughItsClosingBrace() {
        let text = "@media (min-width: 40em) {\n  .a { color: red; }\n}\n.b { }\n"
        let symbols = StylesheetOutline.symbols(in: text, language: .css)
        guard let media = symbols.first(where: { $0.name.hasPrefix("@media") }) else { return XCTFail("no @media symbol") }
        let closingBrace = (text as NSString).range(of: "\n}\n").location + 1
        XCTAssertEqual(media.scopeRange, NSRange(location: media.range.location, length: closingBrace + 1 - media.range.location),
                       "the scope ends after the `}`, not before it")
    }
}
