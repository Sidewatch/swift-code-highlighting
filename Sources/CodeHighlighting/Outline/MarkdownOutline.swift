import Foundation

/// Extracts a Markdown document's ATX headings (`#`…`######`) as outline `Symbol`s —
/// Markdown has no tree-sitter symbol query, so the structure outline falls back to
/// this. Headings inside fenced code blocks (``` / ~~~) are skipped so a `#` comment
/// in a code sample isn't mistaken for a heading, and CommonMark's 3-space cap on
/// ATX indentation is enforced so a `#` line in an indented (4-space) code block
/// isn't either.
///
/// Each heading gets a `scopeRange` spanning from its own line to the next heading of
/// the *same or higher* level, so the shared containment tree-builder nests a document
/// by heading level (H2 under H1, H3 under H2) exactly like it nests code by braces.
public enum MarkdownOutline {

    public static func headings(in text: String) -> [Symbol] {
        let ns = text as NSString
        let scanner = UTF16LineScanner(ns)
        var raw: [Heading] = []
        var inFence = false
        for line in scanner.lines() {
            if line.isFence(in: scanner) { inFence.toggle(); continue }
            guard !inFence, let h = Heading(line: line, in: scanner) else { continue }
            raw.append(h)
        }
        return raw.enumerated().map { i, h in
            // Scope runs to the next same-or-higher heading (or the document's end).
            let end = raw[(i + 1)...].first(where: { $0.level <= h.level })?.location ?? ns.length
            let scope = NSRange(location: h.location, length: max(h.length, end - h.location))
            return Symbol(name: h.name, kind: .heading, range: NSRange(location: h.location, length: h.length),
                          line: h.line, scopeRange: scope)
        }
    }

    /// One ATX heading: `#`s, a space, a title. CommonMark caps its indentation at 3 spaces —
    /// 4+ (or a tab) is an indented code block, whose `#` comments are not headings.
    private struct Heading {
        let level: Int, name: String, location: Int, length: Int, line: Int

        init?(line: UTF16LineScanner.Line, in scanner: UTF16LineScanner) {
            let (indent, spacesOnly, contentStart) = line.indentation(in: scanner)
            var i = contentStart
            guard i < line.contentEnd, scanner.buf[i] == 0x23 /* # */, indent <= 3, spacesOnly else { return nil }
            var hashes = 0
            while i < line.contentEnd, scanner.buf[i] == 0x23 { hashes += 1; i += 1 }
            guard hashes <= 6, i == line.contentEnd || scanner.buf[i] == 0x20 else { return nil }   // ATX requires a space
            let title = scanner.ns.substring(with: NSRange(location: i, length: line.contentEnd - i))
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            guard !title.isEmpty else { return nil }
            level = hashes; name = title; location = line.start; length = line.end - line.start; self.line = line.number
        }
    }
}
