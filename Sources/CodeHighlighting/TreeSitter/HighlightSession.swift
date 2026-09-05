//
//  HighlightSession.swift
//  CodeHighlighting
//
//  A stateful tree-sitter highlighting session that parses a document **once** and keeps the
//  syntax tree alive across highlight passes.
//
//  Created by David Sherlock on 7/16/26.
//

import AppKit
import CodeLanguage
import SwiftTreeSitter

/// A stateful tree-sitter highlighting session that parses a document **once**
/// and keeps the syntax tree alive across highlight passes.
///
/// The stateless ``TreeSitterHighlighter/highlight(_:in:)`` re-parses the whole
/// buffer on every call — fine for small files, but a per-viewport re-highlight
/// while scrolling a multi-megabyte file re-parses those megabytes every scroll
/// tick. A `HighlightSession` instead:
///
/// - parses the full text once, on the first ``highlight(in:text:clip:)``,
/// - re-highlights any viewport clip from the **cached** tree (query only,
///   no parse),
/// - re-parses **incrementally** on edits via ``noteEdit(range:replacementLength:newText:)``
///   (tree-sitter re-lexes only the changed region),
/// - and drops the tree on ``invalidate()`` (file reload, language change),
///   after which the next highlight performs one fresh full parse.
///
/// The color pipeline is identical to the static path: the grammar's
/// `highlights.scm` with later-pattern-wins precedence, `#eq?`/`#match?`
/// predicates resolved, and recursive injection highlighting.
///
/// - Note: Injected languages (CSS in `<style>`, HTML in PHP, …) are still
///   fully re-parsed per highlight call — only the *host* language's tree is
///   cached. Host-language files dominate the huge-file case, so this is an
///   accepted cost; injection trees can be cached later without API changes.
/// - Important: ``highlight(in:text:clip:)`` must run on the main thread (the
///   resolving query cursor is main-actor-isolated), and `text` must be the
///   exact current contents of `storage`. Only `.foregroundColor` is touched.
/// `@unchecked Sendable` is a checked claim, not a waiver: every field the warm-up queue
/// touches (`tree`, `lastText`, `generation`, `fullParseCount`) is documented as guarded by
/// `stateLock` and is only read or written while holding it. The two `let` fields are
/// immutable, and `parser` is main-thread-only by construction — the warm-up parses on its
/// own private `Parser`, which is the whole reason that field carries the note it does.
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
    private(set) var fullParseCount = 0

    /// Test seam: number of incremental re-parses performed by
    /// ``noteEdit(range:replacementLength:newText:)``.
    private(set) var incrementalParseCount = 0

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

    /// Parses `text` on a background queue and installs the resulting tree, so
    /// opening a huge document never runs the multi-second first parse on the
    /// main thread (the host shows plain text until `completion`, which is what
    /// the regex tier did at open anyway).
    ///
    /// The parse runs on a private parser instance; the session's state is only
    /// touched under the lock, and the parsed tree is **discarded** when the
    /// session learned of any text change while parsing (an edit's `noteEdit`,
    /// or `invalidate()`) or when a tree was installed by another path first.
    /// `completion` always runs on the main queue — check ``hasTree`` there:
    /// false means the warm-up was superseded, so re-warm with the current text.
    ///
    /// `@MainActor` on the completion encodes that contract in the type: hosts touch
    /// main-actor state (their own view controllers) in it, and without the annotation
    /// every such capture is a strict-concurrency diagnostic on the caller's side even
    /// though the dispatch below already guarantees the isolation. Delivered via
    /// `DispatchQueue.main` (not `Task { @MainActor }`) to preserve main-queue FIFO
    /// ordering with everything else the session posts.
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
            let parsed = p.parse(text)
            if let self, let parsed {
                self.stateLock.lock()
                if self.generation == gen, self.tree == nil {
                    self.tree = parsed
                    self.lastText = text
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
        // NOT `lastText == text`. Both strings come from the text storage, NSString-backed,
        // and Swift's `==` on bridged strings walks every UTF-16 unit through the bridge
        // with Unicode canonical equivalence on top: ~10 ms for a 358 KB PHP file, five
        // lookups per sticky-scroll pass, 36% of every scroll step (measured with the
        // scroll probe's profiler on wp-includes/formatting.php). NSString compares the
        // backing stores in bulk, and a parse cache WANTS code-unit identity — the tree
        // was built from exactly those units, canonical equivalence be damned.
        let a = last as NSString, b = text as NSString
        guard a.length == b.length, a.isEqual(to: text) else { return nil }
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

    /// Records a text edit and incrementally re-parses.
    ///
    /// Call this for every storage mutation, **after** the change has been
    /// applied, describing it in the old document's coordinates:
    ///
    /// - Parameters:
    ///   - range: the replaced range in the **old** text (UTF-16 units, i.e.
    ///     the `NSRange` NSTextStorage reports — for an insertion, length 0).
    ///   - replacementLength: the UTF-16 length of the inserted text (0 for a
    ///     deletion).
    ///   - newText: the **full** document text after the edit.
    ///
    /// Byte offsets follow the load-bearing SwiftTreeSitter rule — the parser
    /// consumes UTF-16LE, so a tree-sitter byte offset is the UTF-16 index × 2,
    /// NOT `utf8.count`. `Point`s (row, byte-column) are computed with the same
    /// forward newline scan the injection combined-parse uses.
    ///
    /// If no tree is cached yet this is a no-op (the next highlight parses from
    /// scratch anyway). If the edit is inconsistent with the cached text (out
    /// of bounds, or the lengths don't reconcile), the tree is dropped instead
    /// of edited — the next highlight recovers with one full parse.
    public func noteEdit(range: NSRange, replacementLength: Int, newText: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        generation += 1   // any in-flight warm-up is now parsing superseded text
        guard let tree, let old = lastText else { return }
        let oldNS = old as NSString
        let newNS = newText as NSString
        guard range.location >= 0, range.length >= 0, replacementLength >= 0,
              NSMaxRange(range) <= oldNS.length,
              newNS.length == oldNS.length - range.length + replacementLength else {
            self.tree = nil       // desynced with the cached text: full reparse
            self.lastText = nil   // on the next highlight
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

        if let newTree = parser.parse(tree: tree, string: newText) {
            self.tree = newTree
            lastText = newText
            incrementalParseCount += 1
        } else {
            self.tree = nil
            self.lastText = nil
        }
    }

    /// Highlights `clip` (a viewport range, in `storage` coordinates) from the
    /// cached tree — **no parsing** happens unless this is the first call after
    /// init/``invalidate()``, which parses `text` once.
    ///
    /// Runs the same pipeline as the stateless highlighter: the grammar's
    /// highlights query (later pattern wins, predicates resolved) plus the
    /// recursive injection pass (injections re-parse their sub-documents each
    /// call — see the class note), resolved into the final per-range colors and
    /// applied **diff-aware**: only ranges whose color actually changes are
    /// written, so a pass over an already-settled viewport is zero storage
    /// edits — TextKit 2 reconciles nothing (see
    /// ``TreeSitterHighlighter/applyResolved(hits:clip:defaultColor:into:)``).
    ///
    /// - Parameters:
    ///   - storage: the text storage to color. Only `.foregroundColor` is set.
    ///   - text: the current full document text; must match `storage.string`
    ///     and the text the cached tree was built from (keep the tree current
    ///     via ``noteEdit(range:replacementLength:newText:)``).
    ///   - clip: the range to (re)color; clamped to the storage bounds.
    /// - Note: Must be called on the main thread.
    /// - Returns: whether the pass performed any attribute writes. `false` means
    ///   the clip was already correctly colored — TextKit saw no edit, nothing
    ///   was invalidated, and the host can (must, for scroll smoothness) skip
    ///   its post-pass layout settle.
    /// `@MainActor` rather than the whole class: this method writes into a live text storage,
    /// but the session also runs warm-up parses on a background queue, so isolating the type
    /// would be a lie. Only this entry point is main-thread-bound, as its `- Note` already said.
    @discardableResult
    @MainActor
    public func highlight(in storage: NSTextStorage, text: String, clip: NSRange) -> Bool {
        stateLock.lock()
        if tree == nil {
            tree = parser.parse(text)
            lastText = text
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
        stateLock.unlock()
    }
}
