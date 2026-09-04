//
//  CodeIndenter.swift
//  SwiftCodeHighlighting
//
//  Re-indents code without reformatting it.
//
//  Created by David Sherlock on 8/6/26.
//

import Foundation
import CodeLanguage
import SwiftTreeSitter

/// Rewrites the LEADING WHITESPACE of each line and nothing else — Xcode's ⌃I, not a formatter.
///
/// The distinction is the whole design. A formatter decides where lines break, how declarations
/// are spaced and where braces sit, which needs a per-language model of the language's style.
/// Re-indenting decides one thing per line: how far in it starts. That is derivable from nesting
/// alone, so it generalises across every brace-delimited grammar without a rule table, and it
/// cannot reorder, drop or rewrite a single token — the failure modes a formatter has and this
/// does not.
///
/// Nesting comes from the parse tree rather than from counting braces in the text, because a
/// brace inside a string or a comment is not nesting. Tree-sitter never emits those as bracket
/// tokens (they are interior to the string/comment node), so working from tokens excludes them
/// for free, with no quoting or escape rules to get wrong.
public enum CodeIndenter {

    /// Languages where nesting is delimited by brackets, and only those.
    ///
    /// The exclusions matter more than the inclusions. In Python and YAML indentation IS the
    /// syntax: re-indenting by bracket depth would drive every line to column zero and destroy
    /// the program. Ruby, Lua and Bash nest with keywords (`def`/`end`, `then`/`end`, `if`/`fi`)
    /// that this sees no brackets for, so it would flatten them just as badly. HTML and XML nest
    /// by tags, which is a real algorithm but a different one. Markdown, SQL, TOML and Dockerfile
    /// have no nesting worth restating.
    ///
    /// So the list is a whitelist, never a "parse it and hope". A language absent from it is
    /// refused rather than mangled.
    public static let supportedLanguages: Set<CodeLanguage.Language> = [
        .c, .cpp, .csharp, .css, .dart, .go, .java, .javascript, .json, .jsonc,
        .jsx, .kotlin, .php, .rust, .scala, .swift, .tsx, .typescript,
    ]

    public static func supports(_ language: CodeLanguage.Language) -> Bool {
        supportedLanguages.contains(language)
    }

    /// Re-indents `text`, or returns nil when the language is unsupported or has no grammar.
    ///
    /// - Parameters:
    ///   - text: The source.
    ///   - language: Must be in ``supportedLanguages``.
    ///   - indentUnit: One level. Defaults to four spaces.
    /// - Returns: The re-indented source, or nil if it cannot be done safely.
    public static func reindent(_ text: String,
                                language: CodeLanguage.Language,
                                indentUnit: String = "    ") -> String? {
        guard supports(language) else { return nil }
        guard let root = TreeSitterHighlighter.freshParseRoot(text, language: language) else { return nil }
        let ns = text as NSString
        let (brackets, protectedLines) = scan(root: root, ns: ns)
        return rebuild(ns: ns, brackets: brackets, protectedLines: protectedLines, indentUnit: indentUnit)
    }

    // MARK: - Scanning the tree

    private struct Bracket { let offset: Int; let isOpen: Bool }

    /// One walk of the tree collecting bracket tokens and the lines that must not be touched.
    ///
    /// Iterative rather than recursive: a deeply nested minified file is exactly the input
    /// someone reaches for this on, and that is also the input that overflows a recursive walk.
    private static func scan(root: Node, ns: NSString) -> (brackets: [Bracket], protectedLines: Set<Int>) {
        var brackets: [Bracket] = []
        var protectedLines = Set<Int>()
        let lineOf = LineIndex(ns: ns)
        var stack = [root]
        while let node = stack.popLast() {
            let range = node.range
            guard range.location >= 0, NSMaxRange(range) <= ns.length else { continue }
            if hasFrozenInterior(node.nodeType ?? "") {
                // Its interior is CONTENT (a string's value, a doc block's shape, a JSX tree's
                // tag nesting); only its first line is positioned by the code around it. Not
                // descended: a string with an escape splits into `string_content` fragments whose
                // stray opening brace would count as a bracket and leave depth permanently +1.
                let first = lineOf.line(at: range.location)
                let last = lineOf.line(at: max(range.location, NSMaxRange(range) - 1))
                if last > first { for l in (first + 1)...last { protectedLines.insert(l) } }
                continue
            }
            if node.childCount == 0 {
                if let bracket = bracket(of: node, in: ns) { brackets.append(bracket) }
            } else {
                for i in 0..<node.childCount { if let c = node.child(at: i) { stack.append(c) } }
            }
        }
        brackets.sort { $0.offset < $1.offset }
        return (brackets, protectedLines)
    }

    /// Strings, comments and heredocs carry their own indentation as content; a JSX container's
    /// nesting is TAG nesting, and tags are not bracket tokens. Exact JSX names, never a `jsx_`
    /// prefix: `jsx_expression` exists only inside a container the walk already refused to enter.
    private static func hasFrozenInterior(_ type: String) -> Bool {
        let lowered = type.lowercased()
        return lowered.contains("string") || lowered.contains("comment") || lowered.contains("heredoc")
            || type == "jsx_element" || type == "jsx_self_closing_element" || type == "jsx_fragment"
    }

    /// A leaf that is an ANONYMOUS one-character bracket token — never a named one-character
    /// node like a `string_content` or an operator fragment.
    private static func bracket(of node: Node, in ns: NSString) -> Bracket? {
        let range = node.range
        guard range.length == 1, !node.isNamed else { return nil }
        switch ns.substring(with: range) {
        case "{", "[", "(": return Bracket(offset: range.location, isOpen: true)
        case "}", "]", ")": return Bracket(offset: range.location, isOpen: false)
        default: return nil
        }
    }

    // MARK: - Rewriting

    private static func rebuild(ns: NSString,
                                brackets: [Bracket],
                                protectedLines: Set<Int>,
                                indentUnit: String) -> String {
        var out: [String] = []
        var bracketIdx = 0
        var depth = 0
        var offset = 0
        var lineNo = 0

        while offset <= ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: min(offset, ns.length), length: 0))
            let contentEnd = lineEndExcludingBreak(ns: ns, lineRange: lineRange)
            let content = ns.substring(with: NSRange(location: lineRange.location,
                                                     length: contentEnd - lineRange.location))

            // Depth entering this line: every bracket that closed before it counts.
            while bracketIdx < brackets.count, brackets[bracketIdx].offset < lineRange.location {
                depth += brackets[bracketIdx].isOpen ? 1 : -1
                bracketIdx += 1
            }
            depth = max(0, depth)

            if protectedLines.contains(lineNo) {
                out.append(content)                     // inside a literal: byte for byte
            } else {
                let trimmed = content.drop { $0 == " " || $0 == "\t" }
                if trimmed.isEmpty {
                    out.append("")                      // no trailing whitespace on blank lines
                } else {
                    // A line that OPENS with a closer belongs at its opener's level, not at the
                    // level of the content it closes — otherwise every `}` sits one step too deep.
                    let closesFirst = trimmed.first.map { "})]".contains($0) } ?? false
                    let level = max(0, closesFirst ? depth - 1 : depth)
                    out.append(String(repeating: indentUnit, count: level) + trimmed)
                }
            }

            if NSMaxRange(lineRange) >= ns.length { break }
            offset = NSMaxRange(lineRange)
            lineNo += 1
        }

        // A trailing newline in the input means a final empty line, which `lineRange` cannot
        // report (there is no line there to range over). Restore it so re-indenting does not
        // silently strip the POSIX newline off the end of every file it touches.
        var result = out.joined(separator: "\n")
        if ns.length > 0, ns.character(at: ns.length - 1) == 0x0A { result += "\n" }
        return result
    }

    /// The line's content without its `\n` or `\r\n` terminator.
    private static func lineEndExcludingBreak(ns: NSString, lineRange: NSRange) -> Int {
        var end = NSMaxRange(lineRange)
        if end > lineRange.location, ns.character(at: end - 1) == 0x0A { end -= 1 }
        if end > lineRange.location, ns.character(at: end - 1) == 0x0D { end -= 1 }
        return end
    }

    /// Offset → 0-based line, by binary search over the line starts. Built once: asking
    /// `lineRange(for:)` per node is O(n) each and turns the scan quadratic on a large file.
    private struct LineIndex {
        private let starts: [Int]
        init(ns: NSString) {
            var s = [0]
            for i in 0..<ns.length where ns.character(at: i) == 0x0A { s.append(i + 1) }
            starts = s
        }
        func line(at offset: Int) -> Int {
            var lo = 0, hi = starts.count - 1
            while lo < hi {
                let mid = (lo + hi + 1) / 2
                if starts[mid] <= offset { lo = mid } else { hi = mid - 1 }
            }
            return lo
        }
    }
}
