//
//  StylesheetOutlineTests.swift
//  CodeHighlightingTests
//
//  The stylesheet outline: `/* Section */` banners as headings, rules nested
//  under them, at-rules as scopes, strings/comments inert. Pure text in, so it
//  runs headless with no grammar.
//

import XCTest
@testable import CodeHighlighting

final class StylesheetOutlineTests: XCTestCase {

    /// The example that asked for this: three WordPress-style banners, each
    /// followed by its rules. Banners become headings whose scope reaches the next
    /// banner, so the shared tree builder nests the rules under them.
    func testBannersBecomeSectionsWithTheirRulesNested() {
        let css = """
        /* Widgets */
        .widgets-chooser li.widgets-chooser-selected {
          background-color: #916745;
          color: #fff;
        }

        .widgets-chooser li.widgets-chooser-selected:before,
        .widgets-chooser li.widgets-chooser-selected:focus:before {
          color: #fff;
        }

        /* Nav Menus */
        .nav-menus-php .item-edit:focus:before {
          box-shadow: 0 0 0 1px rgb(176.0046728972, 127.9205607477, 88.9953271028), 0 0 2px 1px #916745;
        }

        /* Responsive Component */
        div#wp-responsive-toggle a:before {
          color: hsl(25.7142857143, 7%, 95%);
        }
        """
        let symbols = StylesheetOutline.symbols(in: css, language: .css)
        XCTAssertEqual(symbols.map(\.name), [
            "Widgets",
            ".widgets-chooser li.widgets-chooser-selected",
            ".widgets-chooser li.widgets-chooser-selected:before, .widgets-chooser li.widgets-chooser-selected:focus:before",
            "Nav Menus",
            ".nav-menus-php .item-edit:focus:before",
            "Responsive Component",
            "div#wp-responsive-toggle a:before",
        ])
        XCTAssertEqual(symbols.map(\.kind), [.heading, .selector, .selector, .heading, .selector, .heading, .selector])
        XCTAssertEqual(symbols.map(\.line), [1, 2, 7, 12, 13, 17, 18], "1-based lines of the banner / the selector's first line")

        let tree = OutlineTree.build(from: symbols)
        XCTAssertEqual(tree.map(\.symbol.name), ["Widgets", "Nav Menus", "Responsive Component"])
        XCTAssertEqual(tree.map(\.children.count), [2, 1, 1], "each section holds exactly the rules under it")
    }

    /// Decorated banners — `=====`, `-----`, the multi-line WordPress core shape —
    /// strip to the words; an inner single `-` is punctuation and survives.
    func testDecoratedBannersStripToTheirWords() {
        let css = """
        /* ===== Header ===== */
        .h {}
        /*------------------------------------------------------------------------------
          2.0 - Navigation
        ------------------------------------------------------------------------------*/
        .n {}
        /**
         * 3.0 - Footer
         */
        .f {}
        """
        let headings = StylesheetOutline.symbols(in: css, language: .css).filter { $0.kind == .heading }
        XCTAssertEqual(headings.map(\.name), ["Header", "2.0 - Navigation", "3.0 - Footer"])
        XCTAssertEqual(headings.map(\.line), [1, 3, 7])
    }

    /// Comments that are not banners: inside a rule, sharing a line with code, prose
    /// paragraphs, `/*!` headers, tool pragmas, and SCSS `//` lines.
    func testNonBannerCommentsAreIgnored() {
        let scss = """
        /*! Theme Name: Example — preserved by minifiers, not a section */
        /* This paragraph explains the whole file in far more than sixty characters of prose text. */
        /* stylelint-disable selector-max-id */
        /* rtl:begin:ignore */
        // Buttons (a line comment, not a banner)
        .btn { color: red; /* fallback */ }
        .a { } /* trailing note on a code line */
        .b {
          /* Inside a rule */
          color: blue;
        }
        /* has a semicolon; in it */
        .c {}
        """
        let symbols = StylesheetOutline.symbols(in: scss, language: .scss)
        XCTAssertTrue(symbols.filter { $0.kind == .heading }.isEmpty, "none of these is a section: \(symbols.map(\.name))")
        XCTAssertEqual(symbols.map(\.name), [".btn", ".a", ".b", ".c"])
    }

    /// At-rules with blocks are scopes: the rules inside nest under `@media`, and
    /// `@mixin` reads as a function. Plain rules never expose their (SCSS-nested)
    /// contents.
    func testAtRulesScopeTheRulesInsideThem() {
        let scss = """
        @mixin clearfix($x) { &:after { content: ""; } }
        @media (max-width: 782px) {
          .a { color: red; }
          .b { .nested { color: blue; } }
        }
        .top { .inner { } }
        """
        let symbols = StylesheetOutline.symbols(in: scss, language: .scss)
        XCTAssertEqual(symbols.map(\.name), ["@mixin clearfix($x)", "@media (max-width: 782px)", ".a", ".b", ".top"])
        XCTAssertEqual(symbols[0].kind, .function)
        XCTAssertEqual(symbols[1].kind, .module)
        XCTAssertNotNil(symbols[1].scopeRange, "an at-rule block is a scope")
        XCTAssertNil(symbols[2].scopeRange, "a selector never is")
        let tree = OutlineTree.build(from: symbols)
        XCTAssertEqual(tree.map(\.symbol.name), ["@mixin clearfix($x)", "@media (max-width: 782px)", ".top"])
        XCTAssertEqual(tree[1].children.map(\.symbol.name), [".a", ".b"])
    }

    /// Braces and semicolons inside strings, and a comment inside a selector list,
    /// must not open blocks, end preludes, or leak into names.
    func testStringsAndInlineCommentsAreInert() {
        let css = """
        .q:before { content: "{"; }
        .u { background: url("data:image/svg+xml;charset=utf8,%3Csvg%3E"); }
        .x, /* legacy */ .y { color: red; }
        .after {}
        """
        let symbols = StylesheetOutline.symbols(in: css, language: .css)
        XCTAssertEqual(symbols.map(\.name), [".q:before", ".u", ".x, .y", ".after"])
        XCTAssertEqual(symbols.map(\.line), [1, 2, 3, 4])
    }

    /// A minified stylesheet still walks (every rule on line 1), and past the
    /// selector limit only the structure survives — a list of thousands is not a map.
    func testMinifiedAndOversizedStylesheets() {
        let minified = ".a{color:red}.b{color:blue}@media print{.c{display:none}}"
        let small = StylesheetOutline.symbols(in: minified, language: .css)
        XCTAssertEqual(small.map(\.name), [".a", ".b", "@media print", ".c"])
        XCTAssertEqual(Set(small.map(\.line)), [1])

        let huge = "/* Big */\n" + (0...StylesheetOutline.selectorLimit).map { ".r\($0){}" }.joined() + "@media print{.p{}}"
        let symbols = StylesheetOutline.symbols(in: huge, language: .css)
        XCTAssertEqual(symbols.map(\.name), ["Big", "@media print"], "sections and at-rules stay; the selectors go")
    }

    func testSupportsBraceStylesheetsOnly() {
        XCTAssertTrue(StylesheetOutline.supports(.css))
        XCTAssertTrue(StylesheetOutline.supports(.scss))
        XCTAssertTrue(StylesheetOutline.supports(.less))
        XCTAssertFalse(StylesheetOutline.supports(.sass), "indented syntax has no braces to walk")
        XCTAssertFalse(StylesheetOutline.supports(.html))
    }
}
