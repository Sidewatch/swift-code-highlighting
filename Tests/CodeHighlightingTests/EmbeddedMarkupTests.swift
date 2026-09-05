//
//  EmbeddedMarkupTests.swift
//  Tests for SwiftCodeHighlighting
//
//  Region splitting for single-file components (Astro / Vue / Svelte).
//
//  Created by David Sherlock on 7/30/26.
//

import XCTest
import AppKit
import CodeLanguage
@testable import CodeHighlighting

/// Distinct color per role so tests can assert which role a range received.
private struct SFCColors: TokenColorProviding {
    func color(for kind: TokenKind) -> NSColor {
        switch kind {
        case .comment: return .red
        case .string:  return .green
        case .keyword: return .blue
        case .type:    return .purple
        case .number:  return .orange
        default:       return .brown
        }
    }
    var foreground: NSColor { .black }
}

// `@MainActor`: these exercise the highlighting entry points, which are main-actor
// isolated because they write attributes into a live text storage. XCTest already runs
// test methods on the main thread, so this states the existing reality.
/// Tests for `EmbeddedMarkupHighlighter`: which single-file-component languages it supports and
/// the regions it carves out of them.
@MainActor
final class EmbeddedMarkupTests: XCTestCase {

    private typealias H = EmbeddedMarkupHighlighter

    /// `regions(in:language:)` on `source`, as `(substring, language)` pairs.
    private func regions(_ source: String, _ language: Language) -> [(text: String, lang: Language)] {
        let ns = source as NSString
        return H.regions(in: ns, language: language).map { (ns.substring(with: $0.range), $0.language) }
    }

    // MARK: - Which languages use this tier

    func testSupportsOnlySingleFileComponents() {
        XCTAssertTrue(H.supports(.astro))
        XCTAssertTrue(H.supports(.vue))
        XCTAssertTrue(H.supports(.svelte))
        XCTAssertFalse(H.supports(.html))
        XCTAssertFalse(H.supports(.swift))
        XCTAssertNil(H(language: .html, colors: SFCColors()))
        XCTAssertNotNil(H(language: .astro, colors: SFCColors()))
    }

    // MARK: - Astro frontmatter

    func testAstroFrontmatterIsTypeScript() {
        let src = """
        ---
        const x: number = 1;
        ---
        <p>hi</p>
        """
        let r = regions(src, .astro)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.lang, .typescript)
        XCTAssertEqual(r.first?.text, "const x: number = 1;\n")
    }

    /// The fence is only a fence at the very top — a `---` mid-document (an
    /// `<hr>`-ish separator, a string) must not swallow the file.
    func testFrontmatterOnlyRecognizedAtTopOfFile() {
        XCTAssertTrue(regions("<p>a</p>\n---\nnot frontmatter\n---\n", .astro).isEmpty)
    }

    func testUnterminatedFrontmatterIsAllMarkup() {
        XCTAssertTrue(regions("---\nconst x = 1;\n<p>hi</p>", .astro).isEmpty)
    }

    /// Vue/Svelte have no frontmatter — a leading `---` is ordinary content.
    func testFrontmatterIsAstroOnly() {
        XCTAssertTrue(regions("---\nconst x = 1;\n---\n", .vue).isEmpty)
    }

    // MARK: - <style>

    func testStyleBodyIsCSS() {
        let src = "<div/>\n<style>\n.a { color: red; }\n</style>\n"
        let r = regions(src, .astro)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.lang, .css)
        XCTAssertEqual(r.first?.text, "\n.a { color: red; }\n")
    }

    func testStyleLangAttributeSelectsDialect() {
        XCTAssertEqual(regions("<style lang=\"scss\">.a{}</style>", .vue).first?.lang, .scss)
        XCTAssertEqual(regions("<style lang='less'>.a{}</style>", .vue).first?.lang, .less)
        XCTAssertEqual(regions("<style lang=sass>.a{}</style>", .vue).first?.lang, .sass)
        // postcss and Astro's `is:global` are still plain CSS to a highlighter.
        XCTAssertEqual(regions("<style lang=\"postcss\">.a{}</style>", .vue).first?.lang, .css)
        XCTAssertEqual(regions("<style is:global>.a{}</style>", .astro).first?.lang, .css)
    }

    // MARK: - <script>

    /// Astro compiles a bare `<script>` as TypeScript; Vue/Svelte need `lang="ts"`.
    func testScriptDefaultDialectFollowsHost() {
        XCTAssertEqual(regions("<script>let a = 1</script>", .astro).first?.lang, .typescript)
        XCTAssertEqual(regions("<script>let a = 1</script>", .vue).first?.lang, .javascript)
        XCTAssertEqual(regions("<script setup lang=\"ts\">let a = 1</script>", .vue).first?.lang, .typescript)
        XCTAssertEqual(regions("<script lang=\"js\">let a = 1</script>", .astro).first?.lang, .javascript)
    }

    func testJSONScriptBlock() {
        let src = "<script type=\"application/ld+json\">{\"a\":1}</script>"
        XCTAssertEqual(regions(src, .astro).first?.lang, .json)
    }

    func testSelfClosingScriptHasNoBody() {
        XCTAssertTrue(regions("<script src=\"/a.js\" />\n<p>hi</p>", .astro).isEmpty)
    }

    func testEmptyStyleBlockYieldsNoRegion() {
        XCTAssertTrue(regions("<style></style>", .astro).isEmpty)
    }

    // MARK: - Combined

    func testFullComponentSplitsIntoAllThreeLayers() {
        let src = """
        ---
        const title = 'hi';
        ---
        <article class="card">
          <h1>{title}</h1>
        </article>

        <script>
          console.log(1);
        </script>

        <style>
          .card { color: red; }
        </style>
        """
        let r = regions(src, .astro)
        XCTAssertEqual(r.map(\.lang), [.typescript, .typescript, .css])
        XCTAssertTrue(r[0].text.contains("const title"))
        XCTAssertTrue(r[1].text.contains("console.log"))
        XCTAssertTrue(r[2].text.contains(".card"))
        // Regions are ascending and non-overlapping.
        let ranges = H.regions(in: src as NSString, language: .astro).map(\.range)
        for (a, b) in zip(ranges, ranges.dropFirst()) {
            XCTAssertLessThanOrEqual(NSMaxRange(a), b.location)
        }
    }

    /// A `<style>` written inside the frontmatter is TypeScript source, not a
    /// style block — tag scanning starts after the closing fence.
    func testTagsInsideFrontmatterAreNotRegions() {
        let src = """
        ---
        const markup = '<style>.x{}</style>';
        ---
        <p>hi</p>
        """
        let r = regions(src, .astro)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.first?.lang, .typescript)
    }

    // MARK: - Markup complement

    func testComplementCoversEverythingNotEmbedded() {
        let clip = NSRange(location: 0, length: 100)
        let gaps = H.complement(of: [NSRange(location: 10, length: 20), NSRange(location: 50, length: 10)], within: clip)
        XCTAssertEqual(gaps, [NSRange(location: 0, length: 10),
                              NSRange(location: 30, length: 20),
                              NSRange(location: 60, length: 40)])
    }

    func testComplementIsEmptyWhenRegionCoversClip() {
        let clip = NSRange(location: 10, length: 10)
        XCTAssertTrue(H.complement(of: [NSRange(location: 0, length: 100)], within: clip).isEmpty)
    }

    func testComplementWithNoRegionsIsTheWholeClip() {
        let clip = NSRange(location: 5, length: 20)
        XCTAssertEqual(H.complement(of: [], within: clip), [clip])
    }

    // MARK: - Painting

    /// The bug this tier exists for: the flat Astro table has no CSS rules, so a
    /// `<style>` body was left at the default foreground — while its JS keyword
    /// list painted the `in` of `color-mix(in srgb, …)` as a keyword. Whichever
    /// backend paints the region, the markup table must no longer reach it.
    ///
    /// - Note: This asserts the *negative* only. Under `swift test` the grammar
    ///   `.scm` bundles aren't on disk, so `grammars[.css]` carries an almost
    ///   empty query and the tree-sitter tier paints nothing here — see
    ///   `testEmbeddedRegionFallsBackToTheDialectsOwnRegexTable` for the
    ///   positive assertion, which runs on a backend that works headlessly.
    func testStyleBodyIsNoLongerPaintedByTheMarkupTable() throws {
        let src = """
        ---
        const x = 1;
        ---
        <p class="a">hi</p>
        <style>
          .a { background: color-mix(in srgb, red 10%, transparent); }
        </style>
        """
        let storage = NSTextStorage(string: src)
        let h = try XCTUnwrap(H(language: .astro, colors: SFCColors()))
        h.highlight(storage, in: NSRange(location: 0, length: storage.length))

        let inRange = (src as NSString).range(of: "in srgb")
        XCTAssertNotEqual(storage.attribute(.foregroundColor, at: inRange.location, effectiveRange: nil) as? NSColor,
                          SFCColors().color(for: .keyword),
                          "`in` inside color-mix() must not be painted as a JS keyword")
    }

    /// SCSS/Sass/Less deliberately have no tree-sitter grammar (they route around
    /// the CSS one — see the note by that case in `SyntaxHighlighter`), so a
    /// `<style lang="scss">` body always takes the regex-fallback branch. That
    /// makes it the branch this suite can assert positively without the bundles.
    func testEmbeddedRegionFallsBackToTheDialectsOwnRegexTable() throws {
        let src = "<p>hi</p>\n<style lang=\"scss\">\n$brand: red;\n.card { color: $brand; }\n</style>\n"
        let storage = NSTextStorage(string: src)
        let h = try XCTUnwrap(H(language: .astro, colors: SFCColors()))
        h.highlight(storage, in: NSRange(location: 0, length: storage.length))

        let ns = src as NSString
        func color(at needle: String) -> NSColor? {
            storage.attribute(.foregroundColor, at: ns.range(of: needle).location, effectiveRange: nil) as? NSColor
        }
        // The SCSS table paints selectors and `$variables`; the markup table has
        // rules for neither, so these can only come from the embedded tier.
        XCTAssertNotEqual(color(at: ".card"), SFCColors().foreground, "SCSS selector should be colored")
        XCTAssertNotEqual(color(at: "$brand"), SFCColors().foreground, "SCSS variable should be colored")
    }

    /// The markup outside the embedded regions still gets the host table.
    func testMarkupOutsideRegionsStillHighlighted() throws {
        let src = "<style>.a{}</style>\n<p class=\"x\">hi</p>\n"
        let storage = NSTextStorage(string: src)
        let h = try XCTUnwrap(H(language: .astro, colors: SFCColors()))
        h.highlight(storage, in: NSRange(location: 0, length: storage.length))

        let tag = (src as NSString).range(of: "<p")
        XCTAssertEqual(storage.attribute(.foregroundColor, at: tag.location, effectiveRange: nil) as? NSColor,
                       SFCColors().color(for: .keyword),
                       "markup tags outside the style block keep the host language's coloring")
    }

    /// A viewport-sized clip must paint only that clip (the editor re-highlights
    /// per visible range, not per document).
    func testPartialClipLeavesTheRestUntouched() throws {
        let src = "<style>\n.a { color: red; }\n</style>\n<p>hi</p>\n"
        let storage = NSTextStorage(string: src)
        storage.addAttribute(.foregroundColor, value: NSColor.magenta,
                             range: NSRange(location: 0, length: storage.length))
        let h = try XCTUnwrap(H(language: .astro, colors: SFCColors()))

        let tail = (src as NSString).range(of: "<p>hi</p>")
        h.highlight(storage, in: tail)

        // Untouched head keeps the sentinel color.
        XCTAssertEqual(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .magenta)
    }
}
