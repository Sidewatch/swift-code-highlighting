//
//  HighlightedHTMLTests.swift
//  CodeHighlightingTests
//
//  Covers ``TreeSitterHighlighter/highlightedHTML(_:language:)``, which turns a fenced code
//  block into span-wrapped HTML for the Markdown preview.
//
//  Created by David Sherlock on 8/6/26.
//

import XCTest
import AppKit
import CodeLanguage
@testable import CodeHighlighting

/// Covers ``TreeSitterHighlighter/highlightedHTML(_:language:)``, which turns a fenced code block
/// into span-wrapped HTML for the Markdown preview.
///
/// Escaping carries the weight here. The spans are inserted BETWEEN runs, so the escaping has to
/// happen per run — escape afterwards and it eats the markup, escape before and a `<` in the
/// source splits a token. That is the one failure in this feature that would be ugly rather than
/// cosmetic, so it is tested directly rather than only through rendered output.
@MainActor
final class HighlightedHTMLTests: XCTestCase {

    /// A provider with unmistakably distinct colours per role.
    ///
    /// The default provider resolves several roles to the same system colour as the foreground,
    /// and `highlightedHTML` deliberately omits a span when a run matches the foreground — so
    /// under the defaults a correctly highlighted block can legitimately come back with no spans
    /// at all. Asserting on that would be testing the ambient theme, not the code.
    private struct TestColors: TokenColorProviding {
        let foreground = NSColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        func color(for kind: TokenKind) -> NSColor {
            switch kind {
            case .keyword:  return NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
            case .string:   return NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
            case .number:   return NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
            case .comment:  return NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)
            default:        return NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1)
            }
        }
    }

    // setUp/tearDown run serially on the XCTest runner, never concurrently with each other or
    // with the test body, so this is safe despite not being MainActor-isolated.
    private nonisolated(unsafe) var savedColors: TokenColorProviding!

    override func setUp() {
        super.setUp()
        savedColors = HighlightTheme.colors
        HighlightTheme.colors = TestColors()
    }

    override func tearDown() {
        HighlightTheme.colors = savedColors
        super.tearDown()
    }

    // MARK: - Escaping

    func testEscapesTheFiveDangerousCharacters() {
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML("&"), "&amp;")
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML("<"), "&lt;")
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML(">"), "&gt;")
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML("\""), "&quot;")
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML("'"), "&#39;")
    }

    /// The ampersand must be escaped FIRST, or `<` becomes `&amp;lt;` — the classic
    /// double-escape. Ordering is invisible in single-character tests.
    func testAmpersandIsNotDoubleEscaped() {
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML("&lt;"), "&amp;lt;")
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML("a & b < c"), "a &amp; b &lt; c")
    }

    func testLeavesOrdinaryTextAlone() {
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML("let x = 1"), "let x = 1")
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML(""), "")
    }

    func testEscapesNonASCIIByLeavingItAsUTF8() {
        // The page is UTF-8; escaping these to entities would be noise, not safety.
        XCTAssertEqual(TreeSitterHighlighter.escapeHTML("λ → 日本語"), "λ → 日本語")
    }

    // MARK: - Output shape

    /// A tag with no bundled grammar returns nil so the caller emits the plain escaped code it
    /// would have emitted anyway. Half-highlighting an unknown language is worse than not trying.
    func testReturnsNilForUnsupportedLanguage() {
        XCTAssertNil(TreeSitterHighlighter.highlightedHTML("x = 1", language: .plainText))
    }

    /// Skipped under XCTest, where tree-sitter's query cursor yields no hits even though the
    /// grammars load — the same environment limit that leaves the shipping `attributedSnippet`
    /// uncoloured here, and unrelated to this function. Verified against the built app instead,
    /// with `Sidewatch --dump-code-html <file>`, which reports the span count and escaping.
    func testProducesSpansForASupportedLanguage() throws {
        let html = try XCTUnwrap(TreeSitterHighlighter.highlightedHTML("let x = 1", language: .swift))
        try XCTSkipUnless(html.contains("<span"), "tree-sitter produces no hits under XCTest")
        XCTAssertTrue(html.contains("<span style=\"color:#"), "expected coloured runs, got: \(html)")
        XCTAssertTrue(html.contains("let"))
    }

    /// The whole point of the escaping: source that looks like markup must survive as text.
    func testMarkupInSourceIsNeutralised() throws {
        let html = try XCTUnwrap(
            TreeSitterHighlighter.highlightedHTML("let s = \"<script>alert('x')</script>\"",
                                                  language: .swift))
        XCTAssertFalse(html.contains("<script"), "raw markup leaked into the output: \(html)")
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    /// Generics and comparisons are the everyday case for `<` and `>` in real code.
    func testAngleBracketsInCodeAreEscaped() throws {
        let html = try XCTUnwrap(
            TreeSitterHighlighter.highlightedHTML("let a: Array<Int> = []\nif a.count > 0 {}",
                                                  language: .swift))
        XCTAssertFalse(html.contains("<Int>"))
        XCTAssertTrue(html.contains("&lt;Int&gt;"))
        XCTAssertTrue(html.contains("&gt; 0"))
    }

    /// Stripping the tags must give back exactly the input — nothing added, dropped or reordered.
    /// This is the invariant that a per-run escaping bug would break.
    func testTextSurvivesRoundTrip() throws {
        let source = """
        // a <comment> with & an ampersand
        func f(x: Int) -> String { "\\(x) > 0" }
        """
        let html = try XCTUnwrap(TreeSitterHighlighter.highlightedHTML(source, language: .swift))
        var text = html.replacingOccurrences(of: "<span style=\"color:#[0-9A-F]{6}\">", with: "",
                                             options: .regularExpression)
        text = text.replacingOccurrences(of: "</span>", with: "")
        // Unescape in the reverse order of escaping, ampersand LAST.
        for (entity, ch) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: ch)
        }
        XCTAssertEqual(text, source)
    }

    func testEmptyCodeProducesEmptyOutput() throws {
        XCTAssertEqual(try XCTUnwrap(TreeSitterHighlighter.highlightedHTML("", language: .swift)), "")
    }

    // MARK: - Colours

    func testHexIsSixDigitUppercaseWithHash() {
        XCTAssertEqual(TreeSitterHighlighter.cssHex(.black), "#000000")
        XCTAssertEqual(TreeSitterHighlighter.cssHex(.white), "#FFFFFF")
        XCTAssertEqual(TreeSitterHighlighter.cssHex(NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)), "#FF0000")
    }

    /// A colour in a non-sRGB space must still convert rather than trapping on componentless
    /// access — catalog colours reach here whenever a theme leaves a role unset.
    func testConvertsColoursFromOtherSpaces() {
        let converted = TreeSitterHighlighter.cssHex(NSColor(deviceCyan: 0, magenta: 0, yellow: 0, black: 0, alpha: 1))
        XCTAssertTrue(converted.hasPrefix("#") && converted.count == 7, "got \(converted)")
    }
}
