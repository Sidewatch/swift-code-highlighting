//
//  HighlightedHTMLTests.swift
//  CodeHighlightingTests
//
//  The HTML entry falls through the editor's tiers: a language with no grammar is still coloured.
//
//  Created by David Sherlock on 9/24/26.
//

import XCTest
import CodeLanguage
@testable import CodeHighlighting

@MainActor
final class HighlightedHTMLTests: XCTestCase {
    /// SCSS has no vendored grammar (the CSS grammar cannot parse `$vars`, `@mixin`, `%placeholders`
    /// or `//` comments); the editor paints it through the regex tables, and so must the HTML.
    func testALanguageWithoutAGrammarIsColouredThroughTheRegexTier() {
        let scss = "// Design tokens\n$primary: #336699;\n@mixin flex($dir: row) { display: flex; }\n"
        XCTAssertNil(TreeSitterHighlighter.highlightedHTML(scss, language: .scss), "the tree-sitter-only entry has nothing for SCSS")
        XCTAssertEqual(HighlightedHTML.tier(for: .scss), .regex)
        let html = HighlightedHTML.render(scss, language: .scss)
        XCTAssertTrue(html.contains("<span style=\"color:"), html)
        XCTAssertTrue(html.contains("Design tokens"), "the text survives")
        XCTAssertTrue(html.contains("$primary"), html)
        // Distinct roles wear distinct colours: a comment and a keyword-ish at-rule are not one run.
        let colours = Set(html.components(separatedBy: "color:").dropFirst().compactMap { $0.split(separator: "\"").first })
        XCTAssertGreaterThanOrEqual(colours.count, 2, "\(colours)")
    }

    func testTheTierOrderIsTheEditorsAndTheOutputIsEscaped() {
        XCTAssertEqual(HighlightedHTML.tier(for: .vue), .embeddedMarkup)
        XCTAssertEqual(HighlightedHTML.tier(for: .plainText), .regex)
        if TreeSitterHighlighter.supports(.swift) { XCTAssertEqual(HighlightedHTML.tier(for: .swift), .treeSitter) }
        let plain = HighlightedHTML.render("if a < b && c > \"d\" { }", language: .plainText)
        XCTAssertEqual(plain, "if a &lt; b &amp;&amp; c &gt; &quot;d&quot; { }", "plain text: escaped, no spans")
        let vue = HighlightedHTML.render("<template>\n  <div class=\"x\">hi</div>\n</template>\n", language: .vue)
        XCTAssertTrue(vue.contains("&lt;template"), vue)
        XCTAssertFalse(vue.contains("<template>"), "never raw markup")
    }
}
