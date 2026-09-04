//
//  SyntaxHighlighter.swift
//  SwiftCodeHighlighting
//
//  Dependency-light regex syntax highlighter with per-language rules and a
//  family-based fallback, covering every language CodeLanguage recognizes.
//
//  Created by David Sherlock on 7/9/26.
//

import AppKit
import CodeLanguage

/// Dependency-light regex highlighter: per-language rule tables for the common
/// languages, plus a `HighlightFamily` fallback so every language `CodeLanguage`
/// recognizes gets sensible coloring — no grammars or bundles required.
///
/// Use it as the fallback when ``TreeSitterHighlighter`` has no grammar for the
/// language (`TreeSitterHighlighter.supports(_:)` is false).
public final class SyntaxHighlighter: CodeHighlighter {
    /// A compiled pattern paired with the token role it paints.
    private typealias Rule = (regex: NSRegularExpression, kind: TokenKind)

    // Rules are grouped so precedence is correct regardless of authoring order:
    // code rules apply first, then strings and comments are resolved together in
    // one left-to-right scan where the earliest-starting match wins its whole
    // span — so a keyword inside a string/comment stays quiet, a comment marker
    // inside a string ("https://…") can't repaint the string, and a quote inside
    // a comment can't start a string.
    private let codeRules: [Rule]
    private let stringRules: [Rule]
    private let commentRules: [Rule]
    private let colors: TokenColorProviding

    /// Builds the rule tables for `language`, painting with `colors`.
    /// Never fails: an unknown language falls back to its family's rules
    /// (worst case, plain text gets no rules and stays uncolored).
    public convenience init(language: Language, colors: TokenColorProviding) {
        self.init(defs: RuleTables.table(for: language), regexOptions: .anchorsMatchLines, colors: colors)
    }

    /// Shared designated initializer: compiles a `(pattern, kind)` table into
    /// the three rule groups. Backs both the built-in-language init above and
    /// `init(custom:colors:)` (custom language definitions). A pattern that
    /// fails to compile is skipped — never fatal.
    init(defs: [(String, TokenKind)], regexOptions: NSRegularExpression.Options, colors: TokenColorProviding) {
        self.colors = colors
        var code: [Rule] = []
        var strings: [Rule] = []
        var comments: [Rule] = []
        for (pattern, kind) in defs {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else { continue }
            switch kind {
            case .comment: comments.append((regex, kind))
            case .string:  strings.append((regex, kind))
            default:       code.append((regex, kind))
            }
        }
        codeRules = code
        stringRules = strings
        commentRules = comments
    }

    /// Recolors the lines that intersect `editedRange` (expanded to whole lines).
    /// Only the `.foregroundColor` attribute is touched — never `.font`, which
    /// would invalidate layout on every keystroke.
    @MainActor
    public func highlight(_ storage: NSTextStorage, in editedRange: NSRange) {
        let string = storage.string as NSString
        guard string.length > 0 else { return }

        // Clamp like TreeSitterHighlighter.highlight does: the two tiers are
        // interchangeable, so a stale range safe against one must not crash the other.
        let start = string.lineRange(for: NSRange(location: min(editedRange.location, string.length), length: 0)).location
        let end: Int = {
            let e = NSMaxRange(editedRange)
            let clamped = min(e, string.length)
            return NSMaxRange(string.lineRange(for: NSRange(location: max(clamped - 1, 0), length: 0)))
        }()
        let range = NSRange(location: start, length: end - start)
        guard range.length > 0 else { return }

        // Only reset the color — NOT the font. Changing .font invalidates the
        // layout manager's glyphs on every keystroke/scroll, which races with the
        // gutter's glyph queries and can crash. The font is already set once when
        // the storage is built (and rebuilt on font-size change), so leave it alone.
        storage.addAttribute(.foregroundColor, value: colors.foreground, range: range)

        paint(storage, in: range)

        // Same leftover-marker tint as the tree-sitter tier: a marker whose run
        // was just painted comment-colored takes the keyword color.
        let comment = colors.color(for: .comment)
        let keyword = colors.color(for: .keyword)
        CommentKeywords.regex.enumerateMatches(in: storage.string, options: [], range: range) { m, _, _ in
            guard let r = m?.range, r.length > 0, NSMaxRange(r) <= storage.length,
                  let c = storage.attribute(.foregroundColor, at: r.location, effectiveRange: nil) as? NSColor,
                  c.isEqual(comment) else { return }
            storage.addAttribute(.foregroundColor, value: keyword, range: r)
        }
    }

    /// Runs the rule tables over exactly `range` — no line expansion and, unlike
    /// ``highlight(_:in:)``, no reset to the default foreground first.
    ///
    /// The seam ``EmbeddedMarkupHighlighter`` paints its markup spans through: an
    /// SFC's markup is a set of disjoint sub-ranges rather than one contiguous
    /// block, so the caller owns both the reset and the clipping. Matching is
    /// still evaluated against the whole document (a rule may look behind
    /// `range.location`), only the *matches* are confined to `range`.
    func paint(_ storage: NSTextStorage, in range: NSRange) {
        guard range.length > 0 else { return }
        let text = storage.string
        apply(codeRules, to: storage, in: text, range: range)
        applyStringsAndComments(to: storage, in: text, range: range)
    }

    /// Paints every match of `rules` within `range`, in table order.
    private func apply(_ rules: [Rule], to storage: NSTextStorage, in text: String, range: NSRange) {
        for rule in rules {
            let color = colors.color(for: rule.kind)
            rule.regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let r = match?.range else { return }
                storage.addAttribute(.foregroundColor, value: color, range: r)
            }
        }
    }

    /// Strings and comments must be resolved together: applying one group after
    /// the other let a comment marker inside a string literal (`"https://…"`,
    /// `'a--b'`) repaint the rest of the line as a comment, and vice versa.
    /// This walks the range once, left to right, always accepting the
    /// earliest-starting match (longest on a tie) and re-searching any rule
    /// whose next match overlapped an already-accepted span.
    private func applyStringsAndComments(to storage: NSTextStorage, in text: String, range: NSRange) {
        let rules = stringRules + commentRules
        guard !rules.isEmpty else { return }
        let end = NSMaxRange(range)
        var pos = range.location
        // Cached next match per rule: nil = needs (re)searching from `pos`;
        // location == NSNotFound = the rule has no further matches.
        var next = [NSRange?](repeating: nil, count: rules.count)
        while pos < end {
            var best: (range: NSRange, kind: TokenKind)?
            for i in rules.indices {
                if let cached = next[i], cached.location == NSNotFound { continue }
                if next[i] == nil || next[i]!.location < pos {
                    let found = rules[i].regex
                        .firstMatch(in: text, options: [], range: NSRange(location: pos, length: end - pos))?.range
                    next[i] = (found?.length ?? 0) > 0 ? found : NSRange(location: NSNotFound, length: 0)
                }
                guard let m = next[i], m.location != NSNotFound else { continue }
                if best == nil || m.location < best!.range.location
                    || (m.location == best!.range.location && m.length > best!.range.length) {
                    best = (m, rules[i].kind)
                }
            }
            guard let win = best else { break }
            storage.addAttribute(.foregroundColor, value: colors.color(for: win.kind), range: win.range)
            pos = NSMaxRange(win.range)
        }
    }
}
