//
//  HTTPRequestHighlighterTests.swift
//  CodeHighlightingTests
//
//  Tests for `HTTPRequestHighlighter`: method, URL, headers, body and comments each get their
//  token kind, read back through a marker palette.
//
//  Created by David Sherlock on 9/5/26.
//

import XCTest
import AppKit
@testable import CodeHighlighting

/// Tests for `HTTPRequestHighlighter`: method, URL, headers, body and comments each get their
/// token kind, read back through a marker palette.
@MainActor
final class HTTPRequestHighlighterTests: XCTestCase {

    /// One unique colour per token kind so a painted run reverse-maps to its kind.
    private struct Markers: TokenColorProviding {
        static let kinds: [TokenKind] = [.comment, .string, .keyword, .type, .number, .function, .attribute, .variable, .property]
        func color(for kind: TokenKind) -> NSColor {
            NSColor(deviceRed: CGFloat((Self.kinds.firstIndex(of: kind) ?? -1) + 1) / 100, green: 0, blue: 0, alpha: 1)
        }
        var foreground: NSColor { NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 1) }
        static func kind(of color: NSColor) -> TokenKind? {
            guard let c = color.usingColorSpace(.deviceRGB) else { return nil }
            let i = Int(round(c.redComponent * 100)) - 1
            return kinds.indices.contains(i) ? kinds[i] : nil
        }
    }

    private let document = """
    ### Get one user
    GET https://api.example.com/users/1
    Accept: application/json

    {"id": 1}
    """

    private func kinds() -> (at: (String) -> TokenKind?, storage: NSTextStorage) {
        let storage = NSTextStorage(string: document)
        HTTPRequestHighlighter(colors: Markers()).highlight(storage, in: NSRange(location: 0, length: storage.length))
        let ns = storage.string as NSString
        return ({ needle in
            let r = ns.range(of: needle)
            guard r.location != NSNotFound, let color = storage.attribute(.foregroundColor, at: r.location, effectiveRange: nil) as? NSColor else { return nil }
            return Markers.kind(of: color)
        }, storage)
    }

    func testEachPartOfARequestGetsItsRole() {
        let (kind, _) = kinds()
        XCTAssertEqual(kind("### Get"), .comment)
        XCTAssertEqual(kind("GET"), .keyword)
        XCTAssertEqual(kind("https://"), .string)
        XCTAssertEqual(kind("Accept"), .property)
        XCTAssertEqual(kind("application/json"), .string)
    }

    func testTheBodyIsPaintedAsJSON() {
        let (kind, _) = kinds()
        XCTAssertEqual(kind("1}"), .number, "the JSON highlighter reached the body")
        XCTAssertNotNil(kind("\"id\""), "the key is painted, not left at the foreground")
    }

    func testNewlinesAreNeverPainted() {
        let (_, storage) = kinds()
        let ns = storage.string as NSString
        let eol = ns.range(of: "\n").location
        let color = storage.attribute(.foregroundColor, at: eol, effectiveRange: nil) as? NSColor
        XCTAssertNil(color.flatMap(Markers.kind(of:)), "the separator's newline keeps the foreground colour")
    }
}
