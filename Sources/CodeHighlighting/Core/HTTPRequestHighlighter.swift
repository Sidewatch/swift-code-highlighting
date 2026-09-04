import AppKit
import CodeLanguage

/// Highlighter for an HTTP-client request document (the VS Code / JetBrains `.http`
/// format). `CodeLanguage` has no `.http` case and no grammar ships for it, so this
/// is the "minimal pass" fallback: it colors the `### block name` separators, the
/// `METHOD url` line, header names, and hands each request's JSON body to the JSON
/// regex highlighter — reuse over reinvention, since a `SyntaxHighlighter(.json)`
/// colors a sub-range in place without parsing the surrounding non-JSON.
///
/// A small state machine walks the document line by line: a `###` line opens a new
/// block, the first real line in a block is its request line, lines up to the next
/// blank are headers, and everything after that blank (to the next `###` or EOF) is
/// the body. Colors come from the shared `TokenColorProviding`, read live, so a
/// theme switch just needs a re-highlight.
public final class HTTPRequestHighlighter: CodeHighlighter {

    private let colors: TokenColorProviding
    /// The body highlighter — regex JSON, so it colors an arbitrary sub-range
    /// without attempting to parse the request lines around it (a tree-sitter JSON
    /// pass would try to parse the whole `.http` doc and bail).
    private let jsonBody: SyntaxHighlighter

    /// Builds a request highlighter painting with `colors`.
    public init(colors: TokenColorProviding) {
        self.colors = colors
        self.jsonBody = SyntaxHighlighter(language: .json, colors: colors)
    }

    private enum State { case awaitingRequest, headers, body }

    /// Colors the whole document (the tool always passes the full range; the walk
    /// is line-based and cheap for a request buffer). Resets to the default
    /// foreground first so removed tokens don't keep a stale color.
    public func highlight(_ storage: NSTextStorage, in editedRange: NSRange) {
        let ns = storage.string as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard full.length > 0 else { return }
        storage.addAttribute(.foregroundColor, value: colors.foreground, range: full)

        var state = State.awaitingRequest
        var bodyStart: Int?
        var bodyRanges: [NSRange] = []
        var lineStart = 0

        /// Closes the current body run (start → `endExclusive`), if any.
        func closeBody(endExclusive: Int) {
            if let start = bodyStart, endExclusive > start {
                bodyRanges.append(NSRange(location: start, length: endExclusive - start))
            }
            bodyStart = nil
        }

        while lineStart < ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: lineStart, length: 0))
            let content = contentRange(of: lineRange, in: ns)   // line minus its EOL
            let text = ns.substring(with: content)
            let trimmed = text.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("###") || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                closeBody(endExclusive: lineRange.location)
                storage.addAttribute(.foregroundColor, value: colors.color(for: .comment), range: content)
                if trimmed.hasPrefix("###") { state = .awaitingRequest }   // a new block begins
            } else if trimmed.isEmpty {
                if state == .headers { state = .body; bodyStart = NSMaxRange(lineRange) }
            } else {
                switch state {
                case .awaitingRequest:
                    colorRequestLine(content, text: text, into: storage)
                    state = .headers
                case .headers:
                    colorHeaderLine(content, text: text, into: storage)
                case .body:
                    break   // painted as a range by the JSON pass below
                }
            }
            lineStart = NSMaxRange(lineRange)
        }
        closeBody(endExclusive: ns.length)

        for range in bodyRanges where range.length > 0 {
            jsonBody.highlight(storage, in: range)
        }
    }

    /// The `METHOD url` line: first whitespace-delimited token is the method
    /// (keyword color), the remainder is the URL (string color).
    private func colorRequestLine(_ content: NSRange, text: String, into storage: NSTextStorage) {
        let nsText = text as NSString
        let space = nsText.rangeOfCharacter(from: .whitespaces)
        guard space.location != NSNotFound else {
            storage.addAttribute(.foregroundColor, value: colors.color(for: .keyword), range: content)
            return
        }
        let method = NSRange(location: content.location, length: space.location)
        storage.addAttribute(.foregroundColor, value: colors.color(for: .keyword), range: method)
        let urlLoc = content.location + space.location
        let url = NSRange(location: urlLoc, length: content.length - space.location)
        if url.length > 0 {
            storage.addAttribute(.foregroundColor, value: colors.color(for: .string), range: url)
        }
    }

    /// A `Name: value` header line: name (up to the first colon) as a property,
    /// value as a string. Lines without a colon are left at the default color.
    private func colorHeaderLine(_ content: NSRange, text: String, into storage: NSTextStorage) {
        let nsText = text as NSString
        let colon = nsText.range(of: ":")
        guard colon.location != NSNotFound else { return }
        let name = NSRange(location: content.location, length: colon.location)
        storage.addAttribute(.foregroundColor, value: colors.color(for: .property), range: name)
        let valueLoc = content.location + colon.location + 1
        let valueLen = content.length - colon.location - 1
        if valueLen > 0 {
            storage.addAttribute(.foregroundColor, value: colors.color(for: .string),
                                 range: NSRange(location: valueLoc, length: valueLen))
        }
    }

    /// A line's range minus its trailing `\n` / `\r\n`, so per-line coloring never
    /// paints the newline (which would tint the gap before the next line).
    private func contentRange(of lineRange: NSRange, in ns: NSString) -> NSRange {
        var length = lineRange.length
        while length > 0, isEOL(ns.character(at: lineRange.location + length - 1)) { length -= 1 }
        return NSRange(location: lineRange.location, length: length)
    }

    private func isEOL(_ c: unichar) -> Bool { c == 0x0A || c == 0x0D }
}
