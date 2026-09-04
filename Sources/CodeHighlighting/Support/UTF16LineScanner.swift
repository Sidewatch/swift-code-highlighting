import Foundation

/// The lines of a document as UTF-16 offsets, from ONE contiguous copy of the characters:
/// `components(separatedBy:)` materialised every line as a String (~50k allocations at a
/// 2 MB document) just to find the few lines an outline wants, and the offsets fall out of
/// a walk natively — they are the same UTF-16 units `Symbol.range` wants.
struct UTF16LineScanner {
    let ns: NSString
    let buf: [unichar]

    init(_ ns: NSString) {
        self.ns = ns
        var buf = [unichar](repeating: 0, count: ns.length)
        if ns.length > 0 { ns.getCharacters(&buf, range: NSRange(location: 0, length: ns.length)) }
        self.buf = buf
    }

    /// One line: `[start, end)` excludes the newline; `contentEnd` also excludes a CRLF's `\r`.
    struct Line {
        let number: Int, start: Int, end: Int, contentEnd: Int

        /// Leading whitespace: its count, whether it was spaces only, and where content begins.
        func indentation(in scanner: UTF16LineScanner) -> (indent: Int, spacesOnly: Bool, contentStart: Int) {
            var i = start, indent = 0, spacesOnly = true
            while i < contentEnd, UTF16LineScanner.isWhitespace(scanner.buf[i]) {
                if scanner.buf[i] != 0x20 { spacesOnly = false }
                indent += 1; i += 1
            }
            return (indent, spacesOnly, i)
        }

        /// A ``` or ~~~ fence opener/closer.
        func isFence(in scanner: UTF16LineScanner) -> Bool {
            let i = indentation(in: scanner).contentStart
            guard contentEnd - i >= 3 else { return false }
            let c = scanner.buf[i]
            return (c == 0x60 || c == 0x7E) && scanner.buf[i + 1] == c && scanner.buf[i + 2] == c
        }
    }

    /// Every line, top to bottom. A trailing newline yields a final empty line.
    func lines() -> [Line] {
        var out: [Line] = []
        var lineStart = 0, number = 0
        while lineStart <= buf.count {
            var lineEnd = lineStart
            while lineEnd < buf.count, buf[lineEnd] != 0x0A { lineEnd += 1 }
            number += 1
            var contentEnd = lineEnd
            if contentEnd > lineStart, buf[contentEnd - 1] == 0x0D { contentEnd -= 1 }
            out.append(Line(number: number, start: lineStart, end: lineEnd, contentEnd: contentEnd))
            lineStart = lineEnd + 1
        }
        return out
    }

    /// `CharacterSet.whitespaces` membership with an ASCII fast path.
    static func isWhitespace(_ c: unichar) -> Bool {
        if c == 0x20 || c == 0x09 { return true }
        if c < 0x80 { return false }
        guard let s = Unicode.Scalar(c) else { return false }
        return CharacterSet.whitespaces.contains(s)
    }
}
