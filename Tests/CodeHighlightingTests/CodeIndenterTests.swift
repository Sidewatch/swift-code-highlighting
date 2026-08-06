import XCTest
import CodeLanguage
@testable import CodeHighlighting

/// Covers ``CodeIndenter``.
///
/// The contract is that only LEADING WHITESPACE changes. Everything else — every token, every
/// string's contents, the trailing newline — comes out identical. The tests are weighted towards
/// what it must leave alone rather than what it indents, because a re-indenter that gets the
/// indentation slightly wrong is annoying, while one that edits the inside of a string literal
/// has silently changed what the program does.
final class CodeIndenterTests: XCTestCase {

    // MARK: - The invariant

    /// The strongest single check: strip the leading whitespace off both sides and they must be
    /// identical. Anything the indenter touched beyond indentation shows up here — a dropped
    /// token, a rewritten string, a lost line.
    private func assertOnlyIndentationChanged(_ input: String, _ output: String,
                                              file: StaticString = #filePath, line: UInt = #line) {
        func skeleton(_ s: String) -> [String] {
            s.components(separatedBy: "\n").map { String($0.drop { $0 == " " || $0 == "\t" }) }
        }
        XCTAssertEqual(skeleton(input), skeleton(output),
                       "content changed, not just indentation", file: file, line: line)
    }

    // MARK: - Things it must not touch

    /// The case that decides whether this is safe to ship. A multi-line string's interior
    /// whitespace is the VALUE of the string — re-indenting it changes what the program prints.
    func testDoesNotTouchInteriorOfMultiLineStrings() {
        let input = """
        func f() {
        let s = \"\"\"
                deliberately
                    ragged
        \"\"\"
        }
        """
        let out = CodeIndenter.reindent(input, language: .swift)!
        XCTAssertTrue(out.contains("        deliberately"), "string interior was re-indented:\n\(out)")
        XCTAssertTrue(out.contains("            ragged"), "string interior was re-indented:\n\(out)")
    }

    /// A brace inside a string is text. If depth came from counting characters rather than
    /// tokens, this would open a level that never closes and skew the rest of the file.
    func testBracesInsideStringsDoNotChangeDepth() {
        let input = """
        func f() {
        let a = "{{{"
        let b = 1
        }
        """
        let out = CodeIndenter.reindent(input, language: .swift)!
        XCTAssertTrue(out.contains("\n    let b = 1"), "string braces leaked into depth:\n\(out)")
        XCTAssertTrue(out.contains("\"{{{\""), "the string itself was altered:\n\(out)")
        assertOnlyIndentationChanged(input, out)
    }

    /// Same hazard, in a comment.
    func testBracesInsideCommentsDoNotChangeDepth() {
        let input = """
        func f() {
        // a stray { in a comment
        let b = 1
        }
        """
        let out = CodeIndenter.reindent(input, language: .swift)!
        XCTAssertTrue(out.contains("\n    let b = 1"), "comment braces leaked into depth:\n\(out)")
    }

    /// Stripping the final newline would leave a spurious no-newline-at-EOF on every file
    /// the command touches — a diff on every save.
    func testPreservesTrailingNewline() {
        XCTAssertEqual(CodeIndenter.reindent("let a = 1\n", language: .swift), "let a = 1\n")
        XCTAssertEqual(CodeIndenter.reindent("let a = 1", language: .swift), "let a = 1")
    }

    func testBlankLinesLoseTrailingWhitespaceButStayBlank() {
        let out = CodeIndenter.reindent("func f() {\n   \nlet a = 1\n}", language: .swift)!
        XCTAssertTrue(out.contains("{\n\n"), "blank line kept trailing whitespace:\n\(out)")
        XCTAssertEqual(out.components(separatedBy: "\n").count, 4, "a line was added or lost")
    }

    // MARK: - Refusal

    /// The exclusions are the point of the whitelist. In Python indentation IS the syntax, and
    /// bracket depth is zero throughout — re-indenting by it would drive every line to column 0
    /// and destroy the program. Refusing is the only correct answer.
    func testRefusesIndentationSignificantLanguages() {
        for lang in [CodeLanguage.Language.python, .yaml, .markdown] {
            XCTAssertFalse(CodeIndenter.supports(lang), "\(lang) must not be supported")
            XCTAssertNil(CodeIndenter.reindent("a:\n  b: 1\n", language: lang), "\(lang) was not refused")
        }
    }

    /// Ruby, Lua and Bash nest with keywords this sees no brackets for, so it would flatten them.
    func testRefusesKeywordDelimitedLanguages() {
        for lang in [CodeLanguage.Language.ruby, .lua, .bash] {
            XCTAssertFalse(CodeIndenter.supports(lang), "\(lang) must not be supported")
            XCTAssertNil(CodeIndenter.reindent("def f\n  x\nend\n", language: lang))
        }
    }

    /// Tag nesting is a real algorithm, but a different one — not this one.
    func testRefusesMarkupLanguages() {
        for lang in [CodeLanguage.Language.html, .xml] {
            XCTAssertFalse(CodeIndenter.supports(lang), "\(lang) must not be supported")
        }
    }

    // MARK: - Indenting

    func testIndentsNestedBraces() {
        let out = CodeIndenter.reindent("func f() {\nif x {\nreturn\n}\n}", language: .swift)!
        XCTAssertEqual(out, """
        func f() {
            if x {
                return
            }
        }
        """)
    }

    /// A closing brace belongs at its OPENER's level. Getting this wrong puts every `}` one step
    /// too deep, which is the most visible way an indenter can be wrong.
    func testClosingBraceSitsAtItsOpenersLevel() {
        let out = CodeIndenter.reindent("class A {\nfunc b() {\n}\n}", language: .swift)!
        XCTAssertEqual(out, "class A {\n    func b() {\n    }\n}")
    }

    func testFlattensOverIndentedCode() {
        let out = CodeIndenter.reindent("func f() {\n                    let a = 1\n}", language: .swift)!
        XCTAssertEqual(out, "func f() {\n    let a = 1\n}")
    }

    func testCustomIndentUnit() {
        XCTAssertEqual(CodeIndenter.reindent("func f() {\nlet a = 1\n}", language: .swift, indentUnit: "\t"),
                       "func f() {\n\tlet a = 1\n}")
        XCTAssertEqual(CodeIndenter.reindent("func f() {\nlet a = 1\n}", language: .swift, indentUnit: "  "),
                       "func f() {\n  let a = 1\n}")
    }

    /// Running it twice must be a no-op, or the command produces a diff every time it is used.
    func testIsIdempotent() {
        let source = "class A {\nfunc b() {\nif c {\nreturn\n}\n}\n}\n"
        let once = CodeIndenter.reindent(source, language: .swift)!
        XCTAssertEqual(CodeIndenter.reindent(once, language: .swift), once)
    }

    /// Brackets other than braces nest too — arrays, argument lists, JSON.
    func testBracketsAndParensNestAsWell() {
        let out = CodeIndenter.reindent("let a = [\n1,\n2\n]", language: .swift)!
        XCTAssertEqual(out, "let a = [\n    1,\n    2\n]")
        XCTAssertEqual(CodeIndenter.reindent("{\n\"a\": [\n1\n]\n}", language: .json),
                       "{\n    \"a\": [\n        1\n    ]\n}")
    }

    // MARK: - Across the supported set

    /// Every whitelisted language must at minimum round-trip its own already-correct output.
    /// A grammar whose bracket tokens this does not recognise would show up as churn.
    func testEverySupportedLanguageIsIdempotentOnItsOwnOutput() {
        let samples: [CodeLanguage.Language: String] = [
            .swift:      "func f() {\nlet a = 1\n}\n",
            .c:          "int main() {\nreturn 0;\n}\n",
            .cpp:        "int main() {\nreturn 0;\n}\n",
            .csharp:     "class A {\nvoid B() {\n}\n}\n",
            .java:       "class A {\nvoid b() {\n}\n}\n",
            .javascript: "function f() {\nreturn 1;\n}\n",
            .typescript: "function f(): number {\nreturn 1;\n}\n",
            .tsx:        "function f() {\nreturn 1;\n}\n",
            .jsx:        "function f() {\nreturn 1;\n}\n",
            .go:         "func main() {\nx := 1\n}\n",
            .rust:       "fn main() {\nlet a = 1;\n}\n",
            .php:        "<?php\nfunction f() {\nreturn 1;\n}\n",
            .css:        "body {\ncolor: red;\n}\n",
            .json:       "{\n\"a\": 1\n}\n",
            .kotlin:     "fun f() {\nval a = 1\n}\n",
            .scala:      "object A {\ndef b = 1\n}\n",
            .dart:       "void main() {\nvar a = 1;\n}\n",
        ]
        for (lang, source) in samples {
            guard let once = CodeIndenter.reindent(source, language: lang) else {
                XCTFail("\(lang) is whitelisted but returned nil"); continue
            }
            XCTAssertEqual(CodeIndenter.reindent(once, language: lang), once, "\(lang) is not idempotent")
            assertOnlyIndentationChanged(source, once)
            XCTAssertTrue(once.contains("\n    "), "\(lang) produced no indentation at all:\n\(once)")
        }
    }

    // MARK: - Robustness

    func testEmptyAndWhitespaceOnlyInputs() {
        XCTAssertEqual(CodeIndenter.reindent("", language: .swift), "")
        XCTAssertEqual(CodeIndenter.reindent("\n", language: .swift), "\n")
        XCTAssertEqual(CodeIndenter.reindent("   \n   \n", language: .swift), "\n\n")
    }

    /// Unbalanced input must not drive the level negative or crash — someone will hit ⌃I
    /// mid-edit, with the file temporarily broken.
    func testUnbalancedBracketsDoNotCrashOrGoNegative() {
        for broken in ["}\n}\n}", "func f() {", "}{", "((((", "))))"] {
            let out = CodeIndenter.reindent(broken, language: .swift)
            XCTAssertNotNil(out, "crashed or refused on: \(broken)")
            XCTAssertFalse(out!.contains("    }\n    }\n    }"), "negative depth leaked as indentation")
        }
    }

    func testCRLFLineEndingsSurvive() {
        // The content must come back intact; the indenter normalises the BREAKS to \n, which is
        // stated behaviour rather than an accident — mixed endings in one file are worse.
        let out = CodeIndenter.reindent("func f() {\r\nlet a = 1\r\n}", language: .swift)!
        XCTAssertTrue(out.contains("    let a = 1"), "CRLF input was not indented:\n\(out)")
        XCTAssertFalse(out.contains("\r"), "carriage returns survived into the output")
    }

    func testDeeplyNestedInputDoesNotOverflow() {
        let depth = 300
        let source = String(repeating: "{\n", count: depth) + "x\n" + String(repeating: "}\n", count: depth)
        let out = CodeIndenter.reindent(source, language: .json)
        XCTAssertNotNil(out, "deep nesting failed")
        XCTAssertTrue(out!.contains(String(repeating: "    ", count: depth) + "x"),
                      "deepest line is at the wrong level")
    }
}
