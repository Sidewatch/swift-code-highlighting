//
//  HighlightSession.swift
//  CodeHighlighting
//
//  A stateful tree-sitter highlighting session that parses a document **once** and keeps the
//  syntax tree alive across highlight passes.
//
//  Created by David Sherlock on 7/16/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AppKit
import CodeLanguage
import SwiftTreeSitter

/// A tree-sitter highlighting session that parses a document once and keeps the tree across
/// passes, unlike the stateless ``TreeSitterHighlighter/highlight(_:in:)``, which re-parses per
/// call. Viewport clips re-highlight from the cached tree, edits re-parse incrementally via
/// ``noteEdit(range:replacementLength:newText:)``, and ``invalidate()`` drops the tree. Only the
/// host language's tree is cached; injected languages still re-parse per call.
/// - Important: ``highlight(in:text:clip:)`` runs on the main thread with `text` exactly the
///   storage's contents. `@unchecked Sendable` holds because every field the warm-up queue
///   touches is guarded by `stateLock`, and `parser` is main-thread-only.
public final class HighlightSession: @unchecked Sendable {

    /// The resolved grammar (language pointer + compiled highlight/injection
    /// queries) this session highlights with.
    private let grammar: TreeSitterHighlighter.Grammar

    /// The `CodeLanguage` this session was created for (drives the symbol
    /// query lookup); nil for the test-seam grammar init.
    private let language: CodeLanguage.Language?

    /// The session's parser; configured once with the grammar's language.
    /// Main-thread only — ``warmUp(text:completion:)`` parses on a private
    /// parser instance, never this one.
    private let parser = Parser()

    /// The cached syntax tree for ``lastText``, or nil before the first parse
    /// / after ``invalidate()`` / after a desynced edit was rejected.
    /// Guarded by ``stateLock``.
    private var tree: MutableTree?

    /// The exact text ``tree`` was parsed from — the "old text" side of the
    /// next ``noteEdit(range:replacementLength:newText:)`` byte/Point math.
    /// Guarded by ``stateLock``.
    private var lastText: String?

    /// A contiguous UTF-16 mirror of the text ``tree`` was parsed from, kept in step by
    /// ``noteEdit(range:replacementLength:newText:)`` and read through ``parse(_:tree:mirror:)``.
    /// SwiftTreeSitter's string reader converts, transcodes and allocates per chunk, and JS and
    /// Python ask for ~50,000 chunks per edit on a 200,000-line file (125 ms a keystroke); this
    /// costs 15 MB and one memmove. Guarded by ``stateLock``.
    private var mirror: [UInt16] = []

    /// Units per read handed to tree-sitter; the lexer asks again when it runs off the end.
    private static let readChunkUnits = 4096

    /// `text` as a contiguous UTF-16 buffer — one `getCharacters` block read.
    private static func mirror(of text: String) -> [UInt16] {
        let ns = text as NSString
        var out = [UInt16](repeating: 0, count: ns.length)
        if ns.length > 0 { ns.getCharacters(&out, range: NSRange(location: 0, length: ns.length)) }
        return out
    }

    /// Parses from scratch (`tree` nil) or re-parses `tree` incrementally, reading `mirror`
    /// directly: every read hands tree-sitter a no-copy view of the next chunk, which
    /// SwiftTreeSitter copies into its own buffer before the lexer touches it.
    private static func parse(_ parser: Parser, tree: MutableTree?, mirror: [UInt16]) -> MutableTree? {
        mirror.withUnsafeBufferPointer { buf -> MutableTree? in
            parser.parse(tree: tree) { byteOffset, _ in
                let unit = byteOffset / 2
                guard let base = buf.baseAddress, unit < buf.count else { return nil }
                let n = min(readChunkUnits, buf.count - unit)
                return Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: UnsafeRawPointer(base + unit)),
                            count: n * 2, deallocator: .none)
            }
        }
    }

    /// Guards `tree`/`lastText`/`generation` between the main thread (highlight,
    /// noteEdit, invalidate — all main-only) and the warm-up queue. The warm-up
    /// thread only holds it for the install, never for the parse itself, so the
    /// main thread is never blocked behind a multi-second background parse.
    private let stateLock = NSLock()

    /// Bumped whenever the session learns its text changed (`noteEdit`,
    /// `invalidate`), so an in-flight ``warmUp(text:completion:)`` parse of
    /// superseded text is discarded on arrival instead of installing a tree
    /// that no longer matches the document. Guarded by ``stateLock``.
    private var generation = 0

    /// Test seam: number of from-scratch parses performed (first highlight
    /// after init/invalidate, or a completed warm-up). A scroll-only workload
    /// must keep this at 1.
    public private(set) var fullParseCount = 0

    /// Test seam: number of incremental re-parses performed by
    /// ``noteEdit(range:replacementLength:newText:)``.
    public private(set) var incrementalParseCount = 0

    /// Creates a session for `language`, or nil when no grammar (with its
    /// query bundle) is loaded for it — the same condition as
    /// ``TreeSitterHighlighter/supports(_:)``. Fall back to the stateless
    /// highlighter or ``SyntaxHighlighter`` when this returns nil.
    public init?(language: CodeLanguage.Language) {
        guard let g = TreeSitterHighlighter.grammar(for: language) else { return nil }
        grammar = g
        self.language = language
        try? parser.setLanguage(g.language)
    }

    /// Test seam: builds a session around a hand-assembled grammar (e.g. a
    /// query compiled from a string), bypassing the resource-bundle lookup —
    /// the `.scm` bundles are absent under headless `swift test`.
    init(grammar: TreeSitterHighlighter.Grammar) {
        self.grammar = grammar
        self.language = nil
        try? parser.setLanguage(grammar.language)
    }

    // MARK: - Background warm-up

    /// Whether a parsed tree is installed (highlight passes will be query-only).
    /// False before the first parse, while a warm-up is still running, and after
    /// ``invalidate()``. Thread-safe.
    public var hasTree: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return tree != nil
    }

    /// Parses `text` on a private background parser and installs the tree, so a huge document's
    /// first parse never blocks the main thread. The tree is discarded if the text changed
    /// meanwhile (`noteEdit`, `invalidate()`) or another path installed one first.
    /// `completion` runs on the main queue (via `DispatchQueue.main`, keeping FIFO order with
    /// the session's other posts); check ``hasTree`` there, and re-warm when it is false.
    public func warmUp(text: String, completion: @escaping @MainActor @Sendable () -> Void) {
        stateLock.lock()
        let gen = generation
        let alreadyInstalled = tree != nil
        stateLock.unlock()
        if alreadyInstalled {
            DispatchQueue.main.async { MainActor.assumeIsolated { completion() } }
            return
        }
        let tsLanguage = grammar.language
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let p = Parser()
            try? p.setLanguage(tsLanguage)
            let mirror = Self.mirror(of: text)
            let parsed = Self.parse(p, tree: nil, mirror: mirror)
            if let self, let parsed {
                self.stateLock.lock()
                if self.generation == gen, self.tree == nil {
                    self.tree = parsed
                    self.lastText = text
                    self.mirror = mirror
                    self.fullParseCount += 1
                }
                self.stateLock.unlock()
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { completion() } }
        }
    }

    // MARK: - Cached-tree accessors (no parsing — nil/empty until a tree exists)

    /// The cached tree iff it was parsed from exactly `text`; nil when no tree
    /// is installed (pre-parse, warming up, invalidated) or the text diverged
    /// (a desync — `noteEdit` normally keeps the tree current on every edit).
    private func currentTree(matching text: String) -> MutableTree? {
        stateLock.lock(); defer { stateLock.unlock() }
        guard let tree, let last = lastText else { return nil }
        // O(1), deliberately. Must not compare contents: any content compare walks the whole
        // document per call (~45 ms on 7.5 MB, five calls per sticky-scroll pass), which makes
        // highlighted scrolling stutter. Keeping the tree equal to the text is `noteEdit`'s job;
        // this only catches a host passing the wrong document, by object identity (NSTextStorage
        // vends one backing string for its lifetime) or, failing that, equal length.
        let a = last as NSString, b = text as NSString
        guard a === b || a.length == b.length else { return nil }
        return tree
    }

    /// Enclosing definition names at `offset` (outermost → innermost) from the
    /// **cached** tree — a node walk, no parse (the static
    /// ``TreeSitterHighlighter/breadcrumbs(at:text:language:)`` re-parses the
    /// whole text per call). Empty until a tree is installed for `text`.
    public func breadcrumbs(at offset: Int, text: String) -> [String] {
        guard let tree = currentTree(matching: text), let root = tree.rootNode else { return [] }
        return TreeSitterHighlighter.breadcrumbs(at: offset, ns: text as NSString, root: root)
    }

    /// Enclosing definition scopes at `offset` (outermost → innermost), each
    /// with the definition node's START offset in `text` (UTF-16 units), from
    /// the **cached** tree — the same node walk as ``breadcrumbs(at:text:)``,
    /// no parse. Backs sticky scroll: the host maps each start offset to the
    /// definition's header line. Empty until a tree is installed for `text`.
    public func breadcrumbScopes(at offset: Int, text: String) -> [(name: String, start: Int)] {
        guard let tree = currentTree(matching: text), let root = tree.rootNode else { return [] }
        return TreeSitterHighlighter.breadcrumbScopes(at: offset, ns: text as NSString, root: root)
    }

    /// Smallest syntax node range strictly larger than `selection` (Expand
    /// Selection), from the **cached** tree — no parse. Nil until a tree is
    /// installed for `text`.
    public func enclosingNodeRange(selection: NSRange, text: String) -> NSRange? {
        guard let tree = currentTree(matching: text), let root = tree.rootNode else { return nil }
        return TreeSitterHighlighter.enclosingNodeRange(selection: selection, ns: text as NSString, root: root)
    }

    /// Range of the next/previous named sibling of the node at `selection`,
    /// from the **cached** tree — no parse. Nil until a tree is installed.
    public func siblingRange(of selection: NSRange, text: String, forward: Bool) -> NSRange? {
        guard let tree = currentTree(matching: text), let root = tree.rootNode,
              let node = TreeSitterHighlighter.nodeSpanning(selection, ns: text as NSString, root: root)
        else { return nil }
        return (forward ? node.nextNamedSibling : node.previousNamedSibling)?.range
    }

    /// Definition symbols in `text` from the **cached** tree — query-only, no
    /// parse (the static ``TreeSitterHighlighter/symbols(in:language:)``
    /// re-parses per call). Empty until a tree is installed for `text`, and for
    /// sessions built via the test seam (no `CodeLanguage` to key the symbol
    /// query).
    public func symbols(text: String) -> [Symbol] {
        guard let language, let tree = currentTree(matching: text) else { return [] }
        return TreeSitterHighlighter.symbols(tree: tree, ns: text as NSString, language: language)
    }

    /// Records a text edit and re-parses incrementally. Call it for every storage mutation, after
    /// the change, with `range` in the old text's UTF-16 units, `replacementLength` the inserted
    /// length and `newText` the full new document. Tree-sitter byte offsets are UTF-16 index × 2
    /// (the parser reads UTF-16LE), not `utf8.count`. A no-op before the first parse; an edit
    /// that does not reconcile with the cached text drops the tree for one full re-parse.
    public func noteEdit(range: NSRange, replacementLength: Int, newText: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        generation += 1   // any in-flight warm-up is now parsing superseded text
        guard let tree, let old = lastText else { return }
        let oldNS = old as NSString
        let newNS = newText as NSString
        guard range.location >= 0, range.length >= 0, replacementLength >= 0,
              NSMaxRange(range) <= oldNS.length,
              newNS.length == oldNS.length - range.length + replacementLength,
              mirror.count == oldNS.length else {
            self.tree = nil       // desynced with the cached text: full reparse
            self.lastText = nil   // on the next highlight
            self.mirror = []
            return
        }

        // Bytes: UTF-16 index × 2. Points: rows from a newline scan, columns in
        // bytes. start/oldEnd scan the OLD text; newEnd scans the NEW text —
        // seeded from the start point's scanner state rather than from 0, since
        // the prefix before `range.location` is identical in both, so it only
        // walks the inserted text instead of re-walking the whole prefix.
        var oldScan = UTF16NewlineScanner(oldNS)
        let startPoint = oldScan.point(at: range.location)
        var newScan = UTF16NewlineScanner(newNS, resumingFrom: oldScan)
        let oldEndPoint = oldScan.point(at: NSMaxRange(range))
        let newEndPoint = newScan.point(at: range.location + replacementLength)

        tree.edit(InputEdit(startByte: range.location * 2,
                            oldEndByte: NSMaxRange(range) * 2,
                            newEndByte: (range.location + replacementLength) * 2,
                            startPoint: startPoint,
                            oldEndPoint: oldEndPoint,
                            newEndPoint: newEndPoint))

        // Mirror the edit, then re-parse from the mirror (see ``mirror``).
        var inserted = [UInt16](repeating: 0, count: replacementLength)
        if replacementLength > 0 {
            newNS.getCharacters(&inserted, range: NSRange(location: range.location, length: replacementLength))
        }
        mirror.replaceSubrange(range.location..<NSMaxRange(range), with: inserted)
        if let newTree = Self.parse(parser, tree: tree, mirror: mirror) {
            self.tree = newTree
            lastText = newText
            incrementalParseCount += 1
        } else {
            self.tree = nil
            self.lastText = nil
            self.mirror = []
        }
    }

    /// Highlights `clip` of `storage` from the cached tree (parsing only on the first call after
    /// init or ``invalidate()``), with the stateless highlighter's pipeline, injections included.
    /// Writes are diff-aware: only runs whose colour changes are written, so a settled viewport
    /// costs zero storage edits. `text` must equal `storage.string`; only `.foregroundColor` is set.
    /// - Returns: whether anything was written; `false` lets the host skip its post-pass layout
    ///   settle, which scroll smoothness depends on.
    @discardableResult
    @MainActor
    public func highlight(in storage: NSTextStorage, text: String, clip: NSRange) -> Bool {
        stateLock.lock()
        if tree == nil {
            let fresh = Self.mirror(of: text)
            tree = Self.parse(parser, tree: nil, mirror: fresh)
            lastText = text
            mirror = fresh
            if tree != nil { fullParseCount += 1 }
        }
        let tree = self.tree
        stateLock.unlock()
        guard let tree else { return false }
        let ns = text as NSString
        let clipped = NSIntersectionRange(clip, NSRange(location: 0, length: storage.length))
        guard clipped.length > 0 else { return false }

        var base = 0
        var hits = TreeSitterHighlighter.collectHits(grammar.highlights, tree: tree, source: ns,
                                                     offset: 0, clip: clipped, nextBase: &base)
        hits += TreeSitterHighlighter.collectInjectionHits(grammar, tree: tree, source: ns,
                                                           offset: 0, clip: clipped, depth: 0,
                                                           nextBase: &base)
        return TreeSitterHighlighter.applyResolved(hits: hits, clip: clipped,
                                                   defaultColor: HighlightTheme.colors.foreground,
                                                   into: storage) > 0
    }

    /// Drops the cached tree (and its text). The next
    /// ``highlight(in:text:clip:)`` performs one full parse. Call on file
    /// reload, external modification, or language change — anywhere the storage
    /// text changed without a matching ``noteEdit(range:replacementLength:newText:)``.
    public func invalidate() {
        stateLock.lock()
        generation += 1   // discard any in-flight warm-up parse on arrival
        tree = nil
        lastText = nil
        mirror = []
        stateLock.unlock()
    }
}
