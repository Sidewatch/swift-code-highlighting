//
//  UTF16NewlineScanner.swift
//  CodeHighlighting
//
//  Forward-only newline scanner over an NSString: converts ascending UTF-16 indices to
//  tree-sitter `Point`s (row = newline count, column = bytes since the last newline, i.e.
//
//  Created by David Sherlock on 9/5/26.
//

import AppKit
import CodeLanguage
import SwiftTreeSitter

/// Forward-only newline scanner over an NSString: converts ascending UTF-16
/// indices to tree-sitter `Point`s (row = newline count, column = bytes since
/// the last newline, i.e. UTF-16 units × 2) in one O(n) pass — shared with
/// `TreeSitterHighlighter.combinedParse` for injection ranges. Characters are
/// read in blocks: `character(at:)` is an ObjC call per index, and a per-char
/// walk of the document prefix was the dominant per-keystroke cost in
/// `noteEdit` (millions of msgsends near the bottom of a large file).
struct UTF16NewlineScanner {
    private let ns: NSString
    private var row = 0
    private var lastNL = -1
    private var scan = 0
    private var block = [unichar](repeating: 0, count: 4096)

    /// Creates a scanner positioned at the start of `ns`.
    init(_ ns: NSString) { self.ns = ns }

    /// Creates a scanner over `ns` that resumes from `other`'s current position
    /// and newline state — for an edit's NEW text, whose prefix up to the edit
    /// point is identical to the old text `other` scanned, so the new-end scan
    /// covers only the inserted text instead of re-walking the whole prefix.
    init(_ ns: NSString, resumingFrom other: UTF16NewlineScanner) {
        self.ns = ns
        row = other.row
        lastNL = other.lastNL
        scan = other.scan
    }

    /// The `Point` at UTF-16 index `idx`. Indices must be asked in ascending
    /// order (the scan never rewinds) and be ≤ `ns.length`.
    mutating func point(at idx: Int) -> Point {
        while scan < idx {
            let n = min(block.count, idx - scan)
            ns.getCharacters(&block, range: NSRange(location: scan, length: n))
            for i in 0..<n where block[i] == 0x0A { row += 1; lastNL = scan + i }
            scan += n
        }
        return Point(row: row, column: (idx - lastNL - 1) * 2)
    }
}
