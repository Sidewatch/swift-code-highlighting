//
//  StylesheetScopeRangeTests.swift
//  CodeHighlightingTests
//
//  Pins `StylesheetOutline` scope ranges: an at-rule's scope runs through its closing brace.
//
//  Created by David Sherlock on 9/5/26.
//

import XCTest
@testable import CodeHighlighting

/// Pins `StylesheetOutline` scope ranges: an at-rule's scope runs through its closing brace.
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
