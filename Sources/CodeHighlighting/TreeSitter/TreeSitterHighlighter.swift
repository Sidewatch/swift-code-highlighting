//
//  TreeSitterHighlighter.swift
//  CodeHighlighting
//
//  Tree-sitter–backed highlighter: parses the buffer into a syntax tree and applies colors from
//  the grammar's `highlights.scm` query.
//
//  Created by David Sherlock on 7/9/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import AppKit
import CodeLanguage
import SwiftTreeSitter
import TreeSitterJSON
import TreeSitterMarkdown
import TreeSitterMarkdownInline
import TreeSitterCSS
import TreeSitterJavaScript
import TreeSitterPython
import TreeSitterRust
import TreeSitterGo
import TreeSitterHTML
import TreeSitterBash
import TreeSitterC
import TreeSitterJava
import TreeSitterRuby
import TreeSitterTypeScript
import TreeSitterTSX
import TreeSitterCPP
import TreeSitterCSharp
import TreeSitterPHP
import TreeSitterYAML
import TreeSitterTOML
import TreeSitterLua
import TreeSitterKotlin
import TreeSitterDart
import TreeSitterDockerfile
import TreeSitterSwift
import TreeSitterScala
import TreeSitterXML
import TreeSitterSQL
import FoundationExtensions

/// Tree-sitter–backed highlighter: parses the buffer into a syntax tree and
/// applies colors from the grammar's `highlights.scm` query. Correct across the
/// whole file (no viewport gaps) and far more accurate than regex.
public final class TreeSitterHighlighter: CodeHighlighter {
    /// A loaded grammar: the language pointer plus its compiled highlight and
    /// (optional) injection queries. Internal (not private) so ``HighlightSession``
    /// can share the loaded grammars and tests can build one from a hand-compiled query.
    struct Grammar {
        let language: SwiftTreeSitter.Language; let highlights: Query; let injections: Query?
        /// HTML: also scan its text for Underscore / `wp.template` tags (see `templateTagHits`).
        var templateTags = false
    }

    /// The bundled grammars. Add a package + a line here to support a language.
    /// `bundle` is the SwiftPM resource-bundle name: `<Product>_<Product>`.
    /// Internal so ``HighlightSession`` resolves languages through the same table.
    /// One builder per language, built cheaply; `grammar(for:)` compiles on first use.
    nonisolated(unsafe) static let grammarBuilders: [CodeLanguage.Language: () -> Grammar?] = {
        // `inherits` prepends base grammars' highlights (TS overlays JS; C++ overlays C).
        // `injectHTMLText` adds an HTML injection for inline `text` (PHP templates).
        func g(_ ptr: OpaquePointer?, _ product: String, inherits: [String] = [], injectHTMLText: Bool = false, extra: String = "", templateTags: Bool = false) -> Grammar? {
            guard let ptr else { return nil }
            let language = SwiftTreeSitter.Language(ptr)
            func build(_ src: String) -> Query? {
                src.isEmpty ? nil : try? Query(language: language, data: Data(src.utf8))
            }
            // Highlights are PRUNED before compiling: patterns that can never
            // paint (all captures map to nil colors) still cost a cursor match
            // per occurrence — see `prunedQuerySource`. Injections must NOT be
            // pruned: their `@injection.*` captures map to no color by design.
            func buildHighlights(_ src: String) -> Query? {
                src.isEmpty ? nil : build(prunedQuerySource(src))
            }
            // `extra` is a Sidewatch supplementary query appended last → wins under
            // later-pattern-wins precedence (e.g. distinguishing JSON keys from values).
            let own = (queryText(product) ?? "") + (extra.isEmpty ? "" : "\n" + extra)
            let combined = inherits.compactMap { queryText($0) }.joined(separator: "\n") + "\n" + own
            guard let highlights = buildHighlights(combined) ?? buildHighlights(own) else { return nil }
            var injSrc = queryText(product, "injections.scm") ?? ""
            if injectHTMLText { injSrc += "\n((text) @injection.content (#set! injection.language \"html\"))\n" }
            return Grammar(language: language, highlights: highlights, injections: injSrc.isEmpty ? nil : build(injSrc), templateTags: templateTags)
        }
        var m: [CodeLanguage.Language: () -> Grammar?] = [:]
        m[.json]       = { g(tree_sitter_json(),       "TreeSitterJSON",
                           extra: "(pair key: (string) @property)\n((number) @number)\n[(true) (false)] @boolean\n(null) @constant.builtin") }
        // JSONC (tsconfig & friends) shares the JSON grammar: upstream
        // tree-sitter-json parses `//` and `/* */` comments as extras.
        m[.jsonc]      = m[.json]
        // CSS custom properties (`--brand-primary`) are captured `@variable` upstream
        // with a `^--` guard; the bare-variable role is nil (see `role(for:)`),
        // so re-capture them as `@property` — sigiled, self-distinguishing tokens
        // that VS Code keeps colored (same hue family as bash's `$VAR` @property).
        m[.css]        = { g(tree_sitter_css(),        "TreeSitterCSS",
                           extra: "((property_name) @property (#match? @property \"^--\"))\n((plain_value) @property (#match? @property \"^--\"))") }
        // JSX patterns live in a separate upstream query file the base highlights
        // don't include; overlay it on every grammar whose parser produces jsx
        // nodes (the JS grammar parses JSX natively; TSX is TypeScript+JSX).
        // The patterns only match jsx_* nodes, so non-JSX files are unaffected.
        let jsx = queryText("TreeSitterJavaScript", "highlights-jsx.scm") ?? ""
        m[.javascript] = { g(tree_sitter_javascript(), "TreeSitterJavaScript", extra: jsx) }
        m[.python]     = { g(tree_sitter_python(),     "TreeSitterPython") }
        m[.rust]       = { g(tree_sitter_rust(),       "TreeSitterRust") }
        m[.go]         = { g(tree_sitter_go(),         "TreeSitterGo") }
        m[.html]       = { g(tree_sitter_html(),       "TreeSitterHTML", templateTags: true) }
        m[.bash]      = { g(tree_sitter_bash(),       "TreeSitterBash") }
        m[.c]          = { g(tree_sitter_c(),          "TreeSitterC") }
        m[.java]       = { g(tree_sitter_java(),       "TreeSitterJava") }
        m[.ruby]       = { g(tree_sitter_ruby(),       "TreeSitterRuby") }
        m[.typescript] = { g(tree_sitter_typescript(), "TreeSitterTypeScript", inherits: ["TreeSitterJavaScript"]) }
        m[.cpp]        = { g(tree_sitter_cpp(),        "TreeSitterCPP", inherits: ["TreeSitterC"]) }
        m[.csharp]     = { g(tree_sitter_c_sharp(),    "TreeSitterCSharp") }
        // PHP `$vars` are captured `(variable_name) @variable` upstream — nil'd by the
        // bare-variable role. Like bash's `$VAR`, they're sigiled tokens VS Code
        // keeps colored, so re-capture as `@property` — except `$this`, whose inner
        // `(name)` keeps the `@variable.builtin` color (this extra would outrank it).
        m[.php]        = { g(tree_sitter_php(),         "TreeSitterPHP", injectHTMLText: true,
                           extra: "((variable_name) @property (#not-eq? @property \"$this\"))") }
        m[.yaml]       = { g(tree_sitter_yaml(),       "TreeSitterYAML") }
        m[.toml]       = { g(tree_sitter_toml(),       "TreeSitterTOML") }
        m[.lua]        = { g(tree_sitter_lua(),        "TreeSitterLua") }
        m[.kotlin]     = { g(tree_sitter_kotlin(),     "TreeSitterKotlin") }
        m[.dart]       = { g(tree_sitter_dart(),       "TreeSitterDart") }
        m[.dockerfile] = { g(tree_sitter_dockerfile(), "TreeSitterDockerfile") }
        m[.swift]      = { g(tree_sitter_swift(),      "TreeSitterSwift") }
        m[.scala]      = { g(tree_sitter_scala(),      "TreeSitterScala") }
        m[.xml]        = { g(tree_sitter_xml(),        "TreeSitterXML") }
        // Upstream's number/float patterns use Lua-style classes ("%d"), which
        // NSRegularExpression matches literally — so numeric literals would stay on
        // the earlier `(literal) @string` capture. Re-capture them with a real
        // regex; appended last, it wins under later-pattern-wins precedence.
        m[.sql]        = { g(tree_sitter_sql(),        "TreeSitterSQL",
                           extra: "((literal) @number (#match? @number \"^[+-]?\\\\d+(\\\\.\\\\d+)?$\"))") }
        // Markdown is upstream's DUAL parser; this entry is the BLOCK grammar only.
        // Its injections.scm routes `(inline)` nodes to `markdownInlineGrammar` and
        // fenced code to the fence's language. Upstream's nvim `@text.*` captures map
        // to no colour here, so the extra re-captures the structure with this table's
        // roles, mirroring the regex tier's markdown palette.
        m[.markdown]   = { g(tree_sitter_markdown(),   "TreeSitterMarkdown", extra: """
            (atx_heading (inline) @keyword)
            (setext_heading (paragraph) @keyword)
            [(atx_h1_marker) (atx_h2_marker) (atx_h3_marker) (atx_h4_marker) (atx_h5_marker) (atx_h6_marker) (setext_h1_underline) (setext_h2_underline)] @keyword
            [(list_marker_plus) (list_marker_minus) (list_marker_star) (list_marker_dot) (list_marker_parenthesis)] @keyword
            [(block_quote_marker) (block_continuation) (thematic_break)] @comment
            [(fenced_code_block_delimiter) (info_string)] @string
            [(link_destination) (link_title)] @string
            (link_label) @property
            """) }

        // TSX has its OWN vendored parser (upstream's second grammar in the
        // tree-sitter-typescript repo — TypeScript + native JSX) but shares the
        // TypeScript query bundle: TS highlights over the JS base, with the JSX
        // overlay appended last. JSX files use it too — TSX is a superset that
        // parses plain JSX, and the shared queries keep tags/attributes/components
        // colored identically across .jsx/.tsx.
        m[.tsx]  = { g(tree_sitter_tsx(), "TreeSitterTypeScript", inherits: ["TreeSitterJavaScript"], extra: jsx) }
        m[.jsx]  = m[.tsx]
        // SCSS/Sass/Less deliberately have NO entry: the CSS grammar tokenizes
        // their variables (`$var`, Less `@var`) as ERROR nodes that swallow the
        // neighboring declarations — no capturable node exists for a query to
        // extend, and the two tiers are strictly either/or (every call site is
        // `TreeSitterHighlighter(language:) ?? SyntaxHighlighter(language:)`, no
        // layering), so they route to the dedicated regex rule sets instead.
        return m
    }()

    private static let grammarLock = NSLock()
    nonisolated(unsafe) private static var grammarCache: [CodeLanguage.Language: Grammar?] = [:]   // guarded by grammarLock

    /// The compiled grammar for `language`, compiled on first request and cached; nil when there
    /// is no builder or its query does not compile. Must stay per-language: compiling every
    /// query on first touch costs 600–750 ms on the main thread at launch. Compiling happens
    /// outside the lock, so a race on one language compiles it twice and keeps one, harmlessly.
    static func grammar(for language: CodeLanguage.Language) -> Grammar? {
        grammarLock.lock()
        if let hit = grammarCache[language] { grammarLock.unlock(); return hit }
        grammarLock.unlock()
        guard let build = grammarBuilders[language] else { return nil }
        let built = build()
        grammarLock.lock(); grammarCache[language] = built; grammarLock.unlock()
        return built
    }

    /// Compiles every language's queries. Call from a BACKGROUND thread at launch so
    /// the first file the user opens finds its grammar ready; a language asked for
    /// before the warm-up reaches it simply compiles on demand.
    public static func warmUpGrammars() {
        for language in grammarBuilders.keys.sorted(by: { $0.rawValue < $1.rawValue }) { _ = grammar(for: language) }
    }

    /// Per-language compile cost, for `--probe-grammars`: (language, milliseconds, compiled).
    public static func measureGrammarCompiles() -> [(language: String, ms: Double, ok: Bool)] {
        grammarBuilders.keys.sorted(by: { $0.rawValue < $1.rawValue }).map { language in
            let t0 = ProcessInfo.processInfo.systemUptime
            let ok = grammarBuilders[language]?() != nil
            return (language.rawValue, (ProcessInfo.processInfo.systemUptime - t0) * 1000, ok)
        }
    }

    /// The markdown INLINE grammar (emphasis, code spans, links), upstream's second parser. Not
    /// in `grammars`: it has no `CodeLanguage.Language` and runs only over the block grammar's
    /// `(inline)` injections, all chunks parsed as one document via `Parser.includedRanges`.
    /// An unclosed delimiter in one chunk can, at worst, pair with one in a later chunk.
    static let markdownInlineGrammar: Grammar? = {
        let language = SwiftTreeSitter.Language(tree_sitter_markdown_inline())
        // Same reasoning as the block entry's extra: upstream's `@text.*`
        // captures map to no color, so re-capture with this table's roles,
        // mirroring the regex tier (code/links string, emphasis type, strong
        // function). Emphasis/strong come FIRST so an inner code span or link
        // keeps its own color under later-pattern-wins precedence.
        let extra = """
            (emphasis) @type
            (strong_emphasis) @function
            (code_span) @string
            [(link_destination) (uri_autolink)] @string
            [(link_text) (link_label) (image_description)] @type
            """
        // SwiftPM bundle naming is `<Package>_<Target>`: both markdown targets
        // live in the ONE tree-sitter-markdown package, so the inline bundle is
        // NOT the `<Product>_<Product>` shape `queryText` assumes.
        func inlineQuery(_ file: String) -> String? {
            guard let url = queryURL(bundle: "TreeSitterMarkdown_TreeSitterMarkdownInline", file: file) else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }
        let own = (inlineQuery("highlights.scm") ?? "") + "\n" + extra
        guard let highlights = try? Query(language: language, data: Data(prunedQuerySource(own).utf8)) else { return nil }
        let injSrc = inlineQuery("injections.scm") ?? ""
        let injections = injSrc.isEmpty ? nil : try? Query(language: language, data: Data(injSrc.utf8))
        return Grammar(language: language, highlights: highlights, injections: injections)
    }()

    /// Reads a query file's text from a grammar product's resource bundle.
    private static func queryText(_ product: String, _ file: String = "highlights.scm") -> String? {
        guard let url = queryURL(bundle: "\(product)_\(product)", file: file) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Finds a query file inside a grammar's resource bundle, handling both the
    /// flat layout (`swift build`) and the deep layout (Xcode).
    private static func queryURL(bundle: String, file: String = "highlights.scm") -> URL? {
        guard let res = Bundle.main.resourceURL else { return nil }
        let base = res.appendingPathComponent("\(bundle).bundle")
        let candidates = [
            base.appendingPathComponent("queries/\(file)"),
            base.appendingPathComponent("Contents/Resources/queries/\(file)"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Maps an injection language name (from injections.scm) to a bundled grammar.
    private static func grammarForInjection(_ name: String) -> Grammar? {
        switch name.lowercased() {
        case "html":                   return grammar(for: .html)
        case "css", "scss":            return grammar(for: .css)
        case "javascript", "js", "jsx": return grammar(for: .javascript)
        case "typescript", "ts":       return grammar(for: .typescript)
        case "json":                   return grammar(for: .json)
        case "python":                 return grammar(for: .python)
        case "ruby":                   return grammar(for: .ruby)
        case "bash", "sh", "shell":    return grammar(for: .bash)
        case "yaml":                   return grammar(for: .yaml)
        case "markdown", "md":         return grammar(for: .markdown)
        // The block grammar's injections.scm tags every `(inline)` node with
        // this pseudo-language; it resolves to the dedicated inline grammar.
        case "markdown_inline",
             "markdown-inline":        return markdownInlineGrammar
        default:                       return grammar(for: CodeLanguage.Language(rawValue: name.lowercased()) ?? .plainText)
        }
    }

    /// Whether a grammar (with its query bundle) is loaded for `language` —
    /// i.e. whether `init?(language:)` would succeed. When false, fall back to
    /// the regex ``SyntaxHighlighter``.
    public static func supports(_ language: CodeLanguage.Language) -> Bool { grammar(for: language) != nil }

    /// How many grammars loaded successfully (a startup sanity check: 0 usually
    /// means the `.bundle` query resources weren't shipped next to the executable).
    public static var loadedCount: Int { grammarBuilders.count }

    /// The loaded tree-sitter language object for `language`. Internal for tests
    /// (lets them compile hand-written queries against a bundled grammar).
    static func tsLanguage(for language: CodeLanguage.Language) -> SwiftTreeSitter.Language? {
        grammar(for: language)?.language
    }

    /// Smallest syntax node whose range is strictly larger than `selection`
    /// (for Expand Selection). Returns nil if unavailable.
    /// - Important: performs a fresh full parse of `text`; on big documents
    ///   prefer ``HighlightSession/enclosingNodeRange(selection:text:)``, which
    ///   walks the session's cached tree instead.
    public static func enclosingNodeRange(selection: NSRange, text: String, language: CodeLanguage.Language) -> NSRange? {
        guard let root = freshParseRoot(text, language: language) else { return nil }
        return enclosingNodeRange(selection: selection, ns: text as NSString, root: root)
    }

    /// Tree-walk half of Expand Selection, against an already-parsed `root`.
    /// Internal so ``HighlightSession`` reuses it with its cached tree.
    static func enclosingNodeRange(selection: NSRange, ns: NSString, root: Node) -> NSRange? {
        guard let node = nodeSpanning(selection, ns: ns, root: root) else { return nil }
        var n = node
        while n.range.length <= selection.length {
            guard let p = n.parent else { return nil }
            n = p
        }
        return n.range
    }

    /// Range of the next/previous named sibling of the node at `selection`.
    /// - Important: performs a fresh full parse of `text`; on big documents
    ///   prefer ``HighlightSession/siblingRange(of:text:forward:)``.
    public static func siblingRange(of selection: NSRange, text: String, language: CodeLanguage.Language, forward: Bool) -> NSRange? {
        guard let root = freshParseRoot(text, language: language) else { return nil }
        guard let node = nodeSpanning(selection, ns: text as NSString, root: root) else { return nil }
        return (forward ? node.nextNamedSibling : node.previousNamedSibling)?.range
    }

    /// Root node of one fresh full parse of `text`, or nil when no grammar is loaded.
    static func freshParseRoot(_ text: String, language: CodeLanguage.Language) -> Node? {
        guard let g = grammar(for: language) else { return nil }
        let parser = Parser()
        try? parser.setLanguage(g.language)
        return parser.parse(text)?.rootNode
    }

    /// The smallest syntax node covering `selection` in an already-parsed tree.
    /// Internal so ``HighlightSession`` reuses it with its cached tree.
    static func nodeSpanning(_ selection: NSRange, ns: NSString, root: Node) -> Node? {
        guard NSMaxRange(selection) <= ns.length else { return nil }
        // SwiftTreeSitter parses strings as UTF-16LE, so a tree-sitter byte offset
        // equals the UTF-16 (NSRange) index × 2 — NOT the UTF-8 byte count.
        let byteStart = selection.location * 2
        let byteLen = selection.length * 2
        return root.descendant(in: UInt32(byteStart)..<UInt32(byteStart + byteLen))
    }

    /// Compiled symbol queries, cached per language (guarded by `symbolCacheLock`).
    /// Genuinely cross-thread: `symbols(in:language:)` runs on ProjectSymbolIndex's scan
    /// queue as well as on main, which is why `symbolCacheLock` exists. The annotation
    /// asserts that guard.
    private nonisolated(unsafe) static var symbolQueryCache: [CodeLanguage.Language: Query] = [:]
    private static let symbolCacheLock = NSLock()

    /// All definition symbols (functions, classes, …) in `text`, ordered by
    /// position. Empty when the language has no symbol query or the grammar
    /// isn't loaded. Thread-safe (the project index calls this off the main queue).
    /// - Important: performs a fresh full parse of `text`; on big open documents
    ///   prefer ``HighlightSession/symbols(text:)``, which queries the cached tree.
    public static func symbols(in text: String, language: CodeLanguage.Language) -> [Symbol] {
        guard let g = grammar(for: language), SymbolQueries.sources[language] != nil else { return [] }
        let parser = Parser()
        try? parser.setLanguage(g.language)
        guard let tree = parser.parse(text) else { return [] }
        return symbols(tree: tree, ns: text as NSString, language: language)
    }

    /// Query half of ``symbols(in:language:)``, against an already-parsed tree.
    /// Internal so ``HighlightSession`` reuses it with its cached tree.
    static func symbols(tree: MutableTree, ns: NSString, language: CodeLanguage.Language) -> [Symbol] {
        guard let g = grammar(for: language), let src = SymbolQueries.sources[language] else { return [] }
        symbolCacheLock.lock()
        var query = symbolQueryCache[language]
        symbolCacheLock.unlock()
        if query == nil {
            guard let q = try? Query(language: g.language, data: Data(src.utf8)) else { return [] }
            symbolCacheLock.lock(); symbolQueryCache[language] = q; symbolCacheLock.unlock()
            query = q
        }
        guard let query else { return [] }
        var found: [(name: String, kind: SymbolKind, range: NSRange, scope: NSRange?)] = []
        let cursor = query.execute(in: tree)
        while let match = cursor.next() {
            for capture in match.captures {
                guard let name = capture.name, let kind = SymbolKind(capture: name) else { continue }
                let r = capture.range
                guard r.length > 0, NSMaxRange(r) <= ns.length else { continue }
                // The captured node is the NAME; its parent is the whole declaration —
                // its range is the scope children nest inside.
                var scope = capture.node.parent?.range
                if let s = scope, s.length == 0 || NSMaxRange(s) > ns.length { scope = nil }
                found.append((ns.substring(with: r), kind, r, scope))
            }
        }
        found.sort { $0.range.location < $1.range.location }

        // Line numbers in ONE forward pass. Must not count each symbol's line separately:
        // splitting the prefix per symbol is O(n·m), over 100 s on 2.8 MB. Sorted ascending,
        // `scanned` only moves forward, so this is O(n) total, read in blocks because
        // `character(at:)` is an ObjC call per index.
        var out: [Symbol] = []
        out.reserveCapacity(found.count)
        var line = 1
        var scanned = 0
        var block = [unichar](repeating: 0, count: 4096)
        for item in found {
            while scanned < item.range.location {
                let n = min(block.count, item.range.location - scanned)
                ns.getCharacters(&block, range: NSRange(location: scanned, length: n))
                for i in 0..<n where block[i] == 0x0A /* \n */ { line += 1 }
                scanned += n
            }
            out.append(Symbol(name: item.name, kind: item.kind, range: item.range, line: line, scopeRange: item.scope))
        }
        return out
    }

    /// What every `hoverInfo` variant returns: the card's kind, highlighted signature and doc
    /// comment, plus the 1-based `line` of the definition, printed beside the defining file
    /// (`box.php:3`) so a mis-attribution reads as one at a glance.
    public typealias HoverInfo = (kind: SymbolKind, signature: NSAttributedString, doc: String, line: Int)

    /// For hover docs: the definition signature and preceding doc comment for `word`, if it is
    /// defined in `text`. Main actor, because it highlights through ``highlight(_:in:)``.
    /// - Important: A fresh full parse per call. On an open document prefer
    ///   ``hoverInfo(for:symbols:in:language:)``; for a known site,
    ///   ``hoverInfo(for:definedAt:kind:in:language:)``. Neither parses.
    @MainActor
    public static func hoverInfo(for word: String, in text: String, language: CodeLanguage.Language) -> HoverInfo? {
        guard word.count > 1 else { return nil }
        return hoverInfo(for: word, symbols: symbols(in: text, language: language), in: text, language: language)
    }

    /// ``hoverInfo(for:in:language:)`` against pre-fetched `symbols` (e.g.
    /// ``HighlightSession/symbols(text:)``), with no parse. Empty `symbols` (a session still
    /// warming up) yields nil: "no info here", never a reason to fall back to a parse.
    @MainActor
    public static func hoverInfo(for word: String, symbols: [Symbol], in text: String, language: CodeLanguage.Language) -> HoverInfo? {
        guard word.count > 1, let sym = symbols.first(where: { $0.name == word }) else { return nil }
        return signatureInfo(kind: sym.kind, at: sym.range.location, line: sym.line, in: text as NSString, language: language)
    }

    /// Hover info for a definition whose site is already known (a ``ProjectSymbolIndex``
    /// `DefLocation`), read straight off `text` with no parse. Nil when `range` no longer holds
    /// `word` (the index can briefly lag the file on disk), rather than guessing at a stale site.
    @MainActor
    public static func hoverInfo(for word: String, definedAt range: NSRange, kind: SymbolKind,
                                 in text: String, language: CodeLanguage.Language) -> HoverInfo? {
        let ns = text as NSString
        guard word.count > 1, range.location >= 0, range.length >= 0,
              NSMaxRange(range) <= ns.length, ns.substring(with: range) == word else { return nil }
        return signatureInfo(kind: kind, at: range.location, line: nil, in: ns, language: language)
    }

    /// Shared tail of the `hoverInfo` variants: the (trimmed) line at `location`
    /// as a highlighted signature, plus the doc comment above it, plus the
    /// 1-based line number — `knownLine` when the caller already has it (a
    /// `Symbol`), else counted from the text.
    @MainActor
    private static func signatureInfo(kind: SymbolKind, at location: Int, line knownLine: Int?, in ns: NSString,
                                      language: CodeLanguage.Language) -> HoverInfo? {
        guard location <= ns.length else { return nil }
        let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
        var signature = ns.substring(with: lineRange).trimmed
        while signature.hasSuffix("{") || signature.hasSuffix("}") || signature.hasSuffix(";") {
            signature = String(signature.dropLast())
        }
        signature = signature.trimmingCharacters(in: .whitespaces)
        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let line = knownLine ?? lineNumber(at: lineRange.location, in: ns)
        return (kind, attributedSnippet(signature, language: language, font: mono),
                docComment(above: lineRange.location, in: ns, language: language), line)
    }

    /// 1-based line of `location`: one pass over the prefix in blocks (the walk
    /// ``symbols(in:language:)`` uses). A hover is one call per 0.4 s and the index
    /// caps files at 500 KB, so this is well under a millisecond.
    private static func lineNumber(at location: Int, in ns: NSString) -> Int {
        var line = 1
        var scanned = 0
        var block = [unichar](repeating: 0, count: 4096)
        while scanned < location {
            let n = min(block.count, location - scanned)
            ns.getCharacters(&block, range: NSRange(location: scanned, length: n))
            for i in 0..<n where block[i] == 0x0A { line += 1 }
            scanned += n
        }
        return line
    }

    /// Syntax-highlights a short code snippet (e.g. a hover signature) into an
    /// attributed string. Appends "{}" so a body-less definition still parses.
    /// Main actor, because it highlights through ``highlight(_:in:)``.
    @MainActor
    public static func attributedSnippet(_ code: String, language: CodeLanguage.Language, font: NSFont) -> NSAttributedString {
        // tree-sitter-php starts in HTML/text mode: a bare signature with no
        // `<?php` opener parses as inline text and yields ZERO captures. Parse
        // behind an opener, then trim it back off along with the appended braces.
        let preamble = language == .php ? "<?php " : ""
        let storage = NSTextStorage(string: preamble + code + " {}",
                                    attributes: [.font: font, .foregroundColor: HighlightTheme.colors.foreground])
        if let hl = TreeSitterHighlighter(language: language) {
            storage.beginEditing()
            hl.highlight(storage, in: NSRange(location: 0, length: storage.length))
            storage.endEditing()
        }
        let start = (preamble as NSString).length
        let len = (code as NSString).length
        guard start + len <= storage.length else { return storage }
        return storage.attributedSubstring(from: NSRange(location: start, length: len))
    }

    /// Syntax-highlights `code` as HTML: escaped text in `<span style="color:…">` runs, coloured
    /// from ``HighlightTheme/colors``, for inside a `<pre><code>`. Nil when no grammar is bundled,
    /// so the caller emits plain escaped code. Not built on ``attributedSnippet(_:language:font:)``,
    /// whose appended `" {}"` would miscolour a whole block's last token. Tree-sitter only: for
    /// the editor's three tiers use ``HighlightedHTML/render(_:language:colors:)``.
    @MainActor
    public static func highlightedHTML(_ code: String, language: CodeLanguage.Language) -> String? {
        guard grammar(for: language) != nil, let hl = TreeSitterHighlighter(language: language) else { return nil }

        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let storage = NSTextStorage(string: code,
                                    attributes: [.font: font, .foregroundColor: HighlightTheme.colors.foreground])
        storage.beginEditing()
        hl.highlight(storage, in: NSRange(location: 0, length: storage.length))
        storage.endEditing()

        return HighlightedHTML.spans(of: storage, fallback: HighlightTheme.colors.foreground)
    }

    /// Escapes the five characters that can end a text run inside HTML. Applied per run, since
    /// spans sit between runs: escaping afterwards would eat the markup. Quotes are escaped too,
    /// so the result is safe in attribute position as well as element content.
    static func escapeHTML(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&":  out += "&amp;"
            case "<":  out += "&lt;"
            case ">":  out += "&gt;"
            case "\"": out += "&quot;"
            case "'":  out += "&#39;"
            default:   out.append(ch)
            }
        }
        return out
    }

    /// An NSColor as `#rrggbb`, via sRGB so a theme colour in any space converts predictably.
    static func cssHex(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Enclosing definition names at `offset` (outermost → innermost) for breadcrumbs,
    /// e.g. ["UserRepository", "findById"].
    /// - Important: performs a fresh full parse of `text` (~620 ms on a 2.8 MB
    ///   Swift file); on open documents prefer ``HighlightSession/breadcrumbs(at:text:)``,
    ///   which walks the session's cached tree in microseconds.
    public static func breadcrumbs(at offset: Int, text: String, language: CodeLanguage.Language) -> [String] {
        guard let root = freshParseRoot(text, language: language) else { return [] }
        return breadcrumbs(at: offset, ns: text as NSString, root: root)
    }

    /// A reusable breadcrumb resolver over one parse of `text`: each call to the closure is a
    /// cached-tree walk, where ``breadcrumbs(at:text:language:)`` re-parses per call (~620 ms on
    /// 2.8 MB). For resolving many offsets, such as every changed line of a diff. Nil when no
    /// grammar is loaded. The closure retains the tree; confine it to the thread that made it.
    public static func breadcrumbResolver(text: String, language: CodeLanguage.Language) -> ((Int) -> [String])? {
        guard let root = freshParseRoot(text, language: language) else { return nil }
        let ns = text as NSString
        return { offset in breadcrumbs(at: offset, ns: ns, root: root) }
    }

    /// Tree-walk half of ``breadcrumbs(at:text:language:)``, against an
    /// already-parsed `root`. Internal so ``HighlightSession`` reuses it.
    static func breadcrumbs(at offset: Int, ns: NSString, root: Node) -> [String] {
        breadcrumbScopes(at: offset, ns: ns, root: root).map(\.name)
    }

    /// The scope-position variant of ``breadcrumbs(at:ns:root:)`` — the same
    /// definition-node walk, but each entry also carries the definition node's
    /// START offset in `ns` (UTF-16 units), outermost → innermost. Hosts map
    /// that offset to the definition's header line (sticky scroll pins those
    /// lines; clicking one jumps to it). Internal so ``HighlightSession``
    /// exposes it against its cached tree.
    static func breadcrumbScopes(at offset: Int, ns: NSString, root: Node) -> [(name: String, start: Int)] {
        guard offset <= ns.length else { return [] }
        let byteOffset = offset * 2   // UTF-16 index → tree-sitter byte offset
        guard let node = root.descendant(in: UInt32(byteOffset)..<UInt32(byteOffset)) else { return [] }
        let keywords = ["function", "method", "class", "struct", "enum", "interface",
                        "namespace", "module", "impl", "trait", "constructor", "object"]
        // A CALL is not a scope. Java's `method_invocation` and Lua's `function_call` contain
        // the words above AND carry a `name` field (the callee), so a caret inside a multi-line
        // call's arguments would read the called method as an enclosing definition, adding a
        // breadcrumb for it and pinning the call's line in sticky scroll.
        let calls = ["call", "invocation"]
        var path: [(name: String, start: Int)] = []
        var cur: Node? = node
        while let n = cur {
            let type = n.nodeType ?? ""
            if keywords.contains(where: { type.contains($0) }),
               !calls.contains(where: { type.contains($0) }),
               let nameNode = n.child(byFieldName: "name"),
               NSMaxRange(nameNode.range) <= ns.length {
                path.insert((ns.substring(with: nameNode.range), n.range.location), at: 0)
            }
            cur = n.parent
        }
        return path
    }

    /// Contiguous comment lines immediately above `location` (a doc block).
    /// The recognized markers come from `language`'s own comment tokens, so a
    /// C-family `#include`/`#define` line (not a comment there) or a shebang is
    /// never absorbed as documentation. Internal for tests.
    static func docComment(above location: Int, in ns: NSString, language: CodeLanguage.Language) -> String {
        let markers = docMarkers(for: language)
        guard !markers.isEmpty else { return "" }
        var lines: [String] = []
        var idx = location
        while idx > 0 {
            let prev = ns.lineRange(for: NSRange(location: idx - 1, length: 0))
            var raw = ns.substring(with: prev)
            while raw.hasSuffix("\n") || raw.hasSuffix("\r") { raw.removeLast() }
            let afterIndent = raw.drop { $0 == " " || $0 == "\t" }   // indentation before the marker
            guard let marker = markers.first(where: { afterIndent.hasPrefix($0) }) else { break }
            if marker == "#", afterIndent.hasPrefix("#!") { break }   // shebang, not a doc line
            var content = String(afterIndent.dropFirst(marker.count))
            if content.hasPrefix(" ") { content.removeFirst() }   // just the conventional space after the marker
            if content.hasSuffix("*/") { content = String(content.dropLast(2)) }
            lines.insert(content, at: 0)   // keep the REST of the spacing (e.g. @param column alignment)
            idx = prev.location
            if prev.location == 0 { break }
        }
        while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    /// Doc-comment markers for `language`, derived from its own comment tokens
    /// (so '#' is a marker for Python/Ruby/Bash but never for C-family files).
    /// "*" is last among the block markers so "/**", "/*", "*/" match first.
    private static func docMarkers(for language: CodeLanguage.Language) -> [String] {
        var markers: [String] = []
        if let line = language.lineCommentToken {
            if line == "//" { markers.append("///") }   // doc variants of the plain token
            if line == "--" { markers.append("---") }
            markers.append(line)
        }
        if let block = language.blockComment {
            if block.open == "/*" {
                markers += ["/**", "/*", "*/", "*"]
            } else {
                markers += [block.open, block.close]
            }
        }
        return markers
    }

    private let grammar: Grammar
    private let parser = Parser()

    /// Creates a highlighter for `language`, or nil when no grammar is loaded
    /// for it (check with ``supports(_:)``; fall back to ``SyntaxHighlighter``).
    public init?(language: CodeLanguage.Language) {
        guard let g = Self.grammar(for: language) else { return nil }
        grammar = g
        try? parser.setLanguage(g.language)
    }

    /// Reparses the whole buffer and recolors the lines that intersect
    /// `editedRange` (expanded to whole lines), including injected languages.
    /// Colors are applied diff-aware (see `applyResolved`): only ranges whose
    /// color actually changes are written, so unchanged regions cost TextKit
    /// nothing to reconcile.
    /// - Note: Must be called on the main thread (the resolving query cursor is
    ///   main-actor-isolated). Only `.foregroundColor` is touched, never `.font`.
    @MainActor
    public func highlight(_ storage: NSTextStorage, in editedRange: NSRange) {
        let full = NSRange(location: 0, length: storage.length)
        let ns = storage.string as NSString
        let range = ns.length == 0 ? full
            : ns.lineRange(for: NSRange(location: min(editedRange.location, ns.length), length: 0))
                .union(ns.lineRange(for: NSRange(location: min(NSMaxRange(editedRange), ns.length), length: 0)))

        guard let tree = parser.parse(storage.string) else { return }

        var base = 0
        var hits = Self.collectHits(grammar.highlights, tree: tree, source: ns,
                                    offset: 0, clip: range, nextBase: &base)
        hits += Self.collectInjectionHits(grammar, tree: tree, source: ns,
                                          offset: 0, clip: range, depth: 0, nextBase: &base)
        Self.applyResolved(hits: hits, clip: NSIntersectionRange(range, full),
                           defaultColor: HighlightTheme.colors.foreground, into: storage)
    }

    /// Whether hosts should draw a small color swatch beside hex color literals.
    /// A rendering preference for the host editor — this class never draws chips itself.
    /// `nonisolated(unsafe)`: a host display preference, set from the settings pane and read
    /// when the host lays out chips — both on the main thread.
    public nonisolated(unsafe) static var showColorChips = true

    /// Matches `#RGB` / `#RRGGBB` / `#RRGGBBAA` hex color literals, for hosts
    /// locating chip positions.
    public static let colorRegex = try? NSRegularExpression(
        pattern: "#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\\b")

    /// Parses a `#RGB` / `#RRGGBB` / `#RRGGBBAA` literal (leading `#` optional)
    /// into an sRGB color; nil when the string isn't a valid hex color.
    public static func colorFromHex(_ hex: String) -> NSColor? {
        var s = Substring(hex)
        if s.hasPrefix("#") { s = s.dropFirst() }
        // Every character must be a hex digit: `UInt64(_:radix:)` accepts a leading sign, so
        // `#+12345` would otherwise decode as a colour.
        guard !s.isEmpty, s.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        if s.count == 3 { s = Substring(s.map { "\($0)\($0)" }.joined()) }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b: CGFloat
        var a: CGFloat = 1
        if s.count == 8 {
            r = CGFloat((v >> 24) & 0xFF) / 255; g = CGFloat((v >> 16) & 0xFF) / 255
            b = CGFloat((v >> 8) & 0xFF) / 255;  a = CGFloat(v & 0xFF) / 255
        } else {
            r = CGFloat((v >> 16) & 0xFF) / 255; g = CGFloat((v >> 8) & 0xFF) / 255; b = CGFloat(v & 0xFF) / 255
        }
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    /// One resolved capture hit: an absolute storage range, its precedence key,
    /// and the color it paints. `pattern` is the capture's patternIndex plus the
    /// pass's base (see `collectHits`), so hits from several query passes sort
    /// into one later-wins order, as if each pass were applied after the last.
    typealias Hit = (range: NSRange, pattern: Int, color: NSColor)

    /// Runs a highlights query over `tree` (parsed from `source`), resolving predicates, and
    /// returns the coloured hits offset into storage coordinates by `offset`, clipped to `clip`.
    /// The cursor is bounded to the clip (bytes = UTF-16 index × 2), so iteration is O(viewport),
    /// not O(document); matches intersecting the range still arrive whole. Each call consumes one
    /// precedence window from `nextBase`, so a later pass (an injection) outranks this one.
    @MainActor
    static func collectHits(_ query: Query, tree: MutableTree, source ns: NSString,
                            offset: Int, clip: NSRange, nextBase: inout Int) -> [Hit] {
        let base = nextBase
        nextBase += 1_000_000
        guard clip.length > 0 else { return [] }   // nothing can paint inside an empty clip
        let cursor = query.execute(in: tree)
        // Clip in source (query) coordinates, clamped to the source bounds.
        let lower = min(max(0, clip.location - offset), ns.length)
        let upper = min(max(lower, NSMaxRange(clip) - offset), ns.length)
        guard upper > lower else { return [] }     // the clip lies wholly outside this source
        cursor.setRange(NSRange(location: lower, length: upper - lower))
        let resolving = ResolvingQueryCursor(cursor: cursor)
        resolving.prepare(with: { r, _ in NSMaxRange(r) <= ns.length ? ns.substring(with: r) : nil })
        var hits: [Hit] = []
        while let match = resolving.next() {
            for capture in match.captures {
                guard let name = capture.name, let color = color(for: name) else { continue }
                let r = capture.range
                guard r.length > 0, NSMaxRange(r) <= ns.length else { continue }
                hits.append((NSRange(location: offset + r.location, length: r.length),
                             base + capture.patternIndex, color))
            }
        }
        return hits
    }

    /// Query-then-paint in one call — the pre-collect pipeline, kept as the
    /// hand-built-query seam for tests (`dumpCaptures` has its own loop and the
    /// product paths use `collectHits` + `applyResolved`).
    @MainActor
    static func applyQuery(_ query: Query, tree: MutableTree, source ns: NSString,
                           offset: Int, clip: NSRange, into storage: NSTextStorage) {
        var base = 0
        apply(hits: collectHits(query, tree: tree, source: ns, offset: offset,
                                clip: clip, nextBase: &base),
              clip: clip, into: storage)
    }

    /// Applies the resolved state of `clip` (`defaultColor` overlaid by `hits`, higher `pattern`
    /// winning) as the minimal set of attribute writes: desired colours are diffed run by run
    /// against the storage and only differing ranges are written. A settled viewport costs zero
    /// writes, so TextKit 2 invalidates nothing; that reconcile is otherwise the largest cost of a
    /// scroll re-highlight. Returns the write count; 0 lets hosts skip their layout settle.
    @discardableResult
    static func applyResolved(hits: [Hit], clip: NSRange, defaultColor: NSColor,
                              into storage: NSTextStorage) -> Int {
        let clipped = NSIntersectionRange(clip, NSRange(location: 0, length: storage.length))
        guard clipped.length > 0 else { return 0 }

        // Desired color per position, painted in ascending precedence so later
        // patterns overwrite earlier ones — same math as sequential application.
        var desired = ContiguousArray<NSColor?>(repeating: nil, count: clipped.length)
        for hit in hits.sorted(by: { $0.pattern < $1.pattern }) {
            let r = NSIntersectionRange(hit.range, clipped)
            guard r.length > 0 else { continue }
            for i in (r.location - clipped.location)..<(NSMaxRange(r) - clipped.location) {
                desired[i] = hit.color
            }
        }

        // The agent's leftovers pop: TODO-family markers inside pure comment runs
        // take the keyword color. Folded into `desired` (not painted after) so the
        // zero-write contract over settled text holds — a post-pass tint would
        // fight the diff below and rewrite every marker on every pass.
        let commentColor = HighlightTheme.colors.color(for: .comment)
        let keywordColor = HighlightTheme.colors.color(for: .keyword)
        CommentKeywords.regex.enumerateMatches(in: storage.string, options: [], range: clipped) { m, _, _ in
            guard let r = m?.range, r.length > 0 else { return }
            let lo = r.location - clipped.location, hi = NSMaxRange(r) - clipped.location
            guard lo >= 0, hi <= desired.count,
                  (lo..<hi).allSatisfy({ desired[$0]?.isEqual(commentColor) ?? false }) else { return }
            for i in lo..<hi { desired[i] = keywordColor }
        }

        // Diff desired runs against the storage's existing colors; collect only
        // the mismatching ranges. Runs are merged by object identity (theme
        // colors are stable per role), with isEqual deciding an actual rewrite.
        var writes: [(range: NSRange, color: NSColor)] = []
        storage.enumerateAttribute(.foregroundColor, in: clipped, options: []) { value, range, _ in
            let existing = value as? NSColor
            var i = range.location
            while i < NSMaxRange(range) {
                let want = desired[i - clipped.location] ?? defaultColor
                var j = i + 1
                while j < NSMaxRange(range), (desired[j - clipped.location] ?? defaultColor) === want { j += 1 }
                if !(existing === want), !(existing?.isEqual(want) ?? false) {
                    if let last = writes.last, NSMaxRange(last.range) == i, last.color === want {
                        writes[writes.count - 1].range.length += j - i   // coalesce across run seams
                    } else {
                        writes.append((NSRange(location: i, length: j - i), want))
                    }
                }
                i = j
            }
        }
        for w in writes {
            storage.addAttribute(.foregroundColor, value: w.color, range: w.range)
            writeObserver?(w.range)
        }
        return writes.count
    }

    /// Diagnostic seam: invoked once per ACTUAL attribute write (the minimal
    /// diff-aware ranges), so hosts/probes can verify the zero-write contract
    /// over settled text. Nil (and free) in production. Main-thread only,
    /// like `highlight` itself.
    public nonisolated(unsafe) static var writeObserver: ((NSRange) -> Void)?

    /// Applies collected capture hits: later `patternIndex` wins (hits are applied
    /// in ascending pattern order so later patterns overwrite earlier ones), and
    /// every range is clipped to `clip` — a hit partially outside is trimmed, one
    /// fully outside is dropped. Internal (not private) so tests can exercise the
    /// precedence + clamping math with precomputed hits.
    static func apply(hits: [(range: NSRange, pattern: Int, color: NSColor)],
                      clip: NSRange, into storage: NSTextStorage) {
        for hit in hits.sorted(by: { $0.pattern < $1.pattern }) {
            let r = NSIntersectionRange(hit.range, clip)
            if r.length > 0 { storage.addAttribute(.foregroundColor, value: hit.color, range: r) }
        }
    }

    /// All injection sites in `tree`, grouped by language and merged into ascending,
    /// non-overlapping ranges, so every chunk of a language parses as one document via
    /// `Parser.includedRanges` (a `<section>` before a PHP block pairs with `</section>` after).
    /// A non-nil `clip` bounds the cursor to O(viewport); off-screen sibling chunks then drop out
    /// of the combined parse, an accepted edge effect. Matches go through a
    /// `ResolvingQueryCursor` so injection predicates are honoured: a plain cursor ignores them
    /// and injects (for example) C into every Lua string call instead of only `ffi.cdef`.
    @MainActor
    private static func injectionSites(_ injQuery: Query, tree: MutableTree, ns: NSString,
                                       clip: NSRange? = nil) -> [(name: String, ranges: [NSRange])] {
        var grouped: [String: [NSRange]] = [:]
        var order: [String] = []
        let cursor = injQuery.execute(in: tree)
        if let clip {
            let lower = min(max(0, clip.location), ns.length)
            let upper = min(max(lower, NSMaxRange(clip)), ns.length)
            if upper > lower { cursor.setRange(NSRange(location: lower, length: upper - lower)) }
        }
        let resolving = ResolvingQueryCursor(cursor: cursor)
        resolving.prepare(with: { r, _ in NSMaxRange(r) <= ns.length ? ns.substring(with: r) : nil })
        var separate: [(name: String, ranges: [NSRange])] = []
        while let match = resolving.next() {
            guard let named = match.injection(with: { r, _ in NSMaxRange(r) <= ns.length ? ns.substring(with: r) : nil }),
                  let content = match.captures(named: "injection.content").first else { continue }
            let r = content.range
            guard r.length > 0, NSMaxRange(r) <= ns.length else { continue }
            if separatelyParsed.contains(named.name) {
                separate.append((named.name, [r]))
                continue
            }
            if grouped[named.name] == nil { order.append(named.name) }
            grouped[named.name, default: []].append(r)
        }
        return order.map { name in (name, mergeAscending(grouped[name]!)) } + separate
    }

    /// Injected languages whose chunks are parsed ONE AT A TIME, never combined. Combining is
    /// right for a PHP template's HTML and wrong for Markdown's inline content, where every
    /// `(inline)` node is its own document: combined, "- `a`\n- `b`" reads as the code span
    /// "a``b" and every later code span swallows text up to the next backtick.
    private static let separatelyParsed: Set<String> = ["markdown_inline"]

    /// Sorts `ranges` ascending and unions overlapping/adjacent ones — tree-sitter
    /// requires included ranges to be ascending and non-overlapping.
    static func mergeAscending(_ ranges: [NSRange]) -> [NSRange] {
        var merged: [NSRange] = []
        for r in ranges.sorted(by: { $0.location < $1.location }) {
            if let last = merged.last, NSMaxRange(last) >= r.location {
                merged[merged.count - 1] = last.union(r)
            } else {
                merged.append(r)
            }
        }
        return merged
    }

    /// Parses the whole of `ns` restricted to `ranges` — one combined document per
    /// injected language. Byte offsets are UTF-16 index × 2 (SwiftTreeSitter parses
    /// UTF-16LE); points come from a single forward newline scan (column in bytes),
    /// block-read via `UTF16NewlineScanner`, since this runs per highlight pass and a
    /// per-character walk costs an ObjC call per UTF-16 unit.
    static func combinedParse(_ sub: Grammar, ns: NSString, ranges: [NSRange]) -> MutableTree? {
        let p = Parser()
        try? p.setLanguage(sub.language)
        var scanner = UTF16NewlineScanner(ns)   // ranges are ascending (mergeAscending)
        p.includedRanges = ranges.map { r in
            let start = scanner.point(at: r.location), end = scanner.point(at: NSMaxRange(r))
            return TSRange(points: start..<end, bytes: UInt32(r.location * 2)..<UInt32(NSMaxRange(r) * 2))
        }
        return p.parse(ns as String)
    }

    /// Recursively collects hits for embedded languages (CSS in `<style>`, HTML in PHP, …),
    /// depth-limited. All chunks of one language share a combined parse (see `injectionSites`),
    /// so ranges stay absolute within `ns`. Visits depth-first, each pass taking a later
    /// `nextBase` window so deeper and later passes win on overlap. Shared with ``HighlightSession``.
    @MainActor
    static func collectInjectionHits(_ g: Grammar, tree: MutableTree, source ns: NSString,
                                     offset: Int, clip: NSRange, depth: Int,
                                     nextBase: inout Int) -> [Hit] {
        guard depth < 3 else { return [] }
        var hits: [Hit] = []
        // A top-level HTML document owns all of `ns`; injected HTML gets its ranges below.
        if depth == 0, g.templateTags {
            // Top-level .html: the JS is coloured; the markup parse itself is not masked here
            // (the incremental session owns that tree), so elements after a `<#` may stay plain.
            let tags = templateTagRanges(in: ns, within: [NSRange(location: 0, length: ns.length)])
            hits += templateTagHits(source: ns, tags: tags, offset: offset, clip: clip, nextBase: &nextBase)
        }
        guard let injQuery = g.injections else { return hits }
        let sourceClip = NSRange(location: max(0, clip.location - offset), length: clip.length)
        for site in injectionSites(injQuery, tree: tree, ns: ns, clip: sourceClip) {
            guard let sub = grammarForInjection(site.name) else { continue }
            guard site.ranges.contains(where: {
                NSIntersectionRange(NSRange(location: offset + $0.location, length: $0.length), clip).length > 0
            }) else { continue }
            // HTML with template tags is parsed from a copy with the tags blanked to spaces:
            // tree-sitter-html reads `<#` as a tag opening and produces no elements at all
            // for the rest of the section. Same UTF-16 length, so every position still holds.
            let tags: (code: [NSRange], expressions: [NSRange], all: [NSRange]) = sub.templateTags
                ? templateTagRanges(in: ns, within: site.ranges) : (code: [], expressions: [], all: [])
            let markup: NSString = tags.all.isEmpty ? ns : maskingTemplateTags(ns, tags.all)
            guard let subTree = combinedParse(sub, ns: markup, ranges: site.ranges) else { continue }
            hits += collectHits(sub.highlights, tree: subTree, source: markup,
                                offset: offset, clip: clip, nextBase: &nextBase)
            hits += collectInjectionHits(sub, tree: subTree, source: markup, offset: offset,
                                         clip: clip, depth: depth + 1, nextBase: &nextBase)
            if !tags.all.isEmpty {
                hits += templateTagHits(source: ns, tags: tags, offset: offset, clip: clip, nextBase: &nextBase)
            }
        }
        return hits
    }

    /// Underscore / `wp.template` tags — `<# js #>`, `{{ expr }}`, `{{{ expr }}}` — are plain text
    /// to the HTML grammar, and WordPress core's Customizer and media templates are made of them.
    /// Found by regex within the HTML-owned `ranges`. All `<# #>` fragments parse as ONE JavaScript document
    /// (combined ranges), so `<# if ( x ) { #> … <# } #>` is a valid program across fragments;
    /// each `{{ }}` interpolation parses alone, as the expression it is.
    private static let templateTagRegex = try! NSRegularExpression(
        pattern: #"<#([\s\S]*?)#>|\{\{\{?([\s\S]*?)\}\}\}?"#)

    /// (`<# #>` fragments, `{{ }}` fragments, whole tags including delimiters), each ascending
    /// and non-overlapping.
    static func templateTagRanges(in ns: NSString, within ranges: [NSRange]) -> (code: [NSRange], expressions: [NSRange], all: [NSRange]) {
        var code: [NSRange] = [], expressions: [NSRange] = [], all: [NSRange] = []
        let text = ns as String
        for r in ranges where r.length > 0 && NSMaxRange(r) <= ns.length {
            for m in templateTagRegex.matches(in: text, range: r) {
                let c = m.range(at: 1), e = m.range(at: 2)
                if c.location != NSNotFound, c.length > 0 { code.append(c) }
                if e.location != NSNotFound, e.length > 0 { expressions.append(e) }
                all.append(m.range)
            }
        }
        return (mergeAscending(code), mergeAscending(expressions), mergeAscending(all))
    }

    /// `ns` with every template tag (delimiters included) replaced by spaces, one per UTF-16
    /// unit, so the markup grammar sees clean HTML at unchanged positions.
    static func maskingTemplateTags(_ ns: NSString, _ all: [NSRange]) -> NSString {
        let m = NSMutableString(string: ns as String)
        for r in all where NSMaxRange(r) <= m.length {
            m.replaceCharacters(in: r, with: String(repeating: " ", count: r.length))
        }
        return m
    }

    /// JavaScript hits for the template tags that intersect `clip`: all `<# #>` fragments parsed
    /// as one combined document, each `{{ }}` expression on its own.
    @MainActor
    static func templateTagHits(source ns: NSString, tags: (code: [NSRange], expressions: [NSRange], all: [NSRange]),
                                offset: Int, clip: NSRange, nextBase: inout Int) -> [Hit] {
        guard !(tags.code.isEmpty && tags.expressions.isEmpty), let js = grammarForInjection("javascript") else { return [] }
        func intersectsClip(_ rs: [NSRange]) -> Bool {
            rs.contains { NSIntersectionRange(NSRange(location: offset + $0.location, length: $0.length), clip).length > 0 }
        }
        var hits: [Hit] = []
        if !tags.code.isEmpty, intersectsClip(tags.code), let tree = combinedParse(js, ns: ns, ranges: tags.code) {
            hits += collectHits(js.highlights, tree: tree, source: ns, offset: offset, clip: clip, nextBase: &nextBase)
        }
        for e in tags.expressions where intersectsClip([e]) {
            guard let tree = combinedParse(js, ns: ns, ranges: [e]) else { continue }
            hits += collectHits(js.highlights, tree: tree, source: ns, offset: offset, clip: clip, nextBase: &nextBase)
        }
        return hits
    }

    /// Strips top-level query patterns whose captures all map to nil colours (punctuation,
    /// operators…) before compiling: they can never paint, but the cursor still yields a match per
    /// occurrence (a third of the Swift query's per-viewport captures). Removing whole patterns
    /// keeps later-pattern-wins order; unrecognised syntax is kept, never pruned, via
    /// ``QuerySourceScanner``. Returns the original source if pruning would leave nothing.
    static func prunedQuerySource(_ src: String) -> String {
        var scanner = QuerySourceScanner(src)
        var out = ""
        var kept = 0
        while let token = scanner.next() {
            switch token {
            case .whitespace(let c): out.unicodeScalars.append(c)
            case .comment(let text), .bare(let text): out += text
            case .pattern(let chunk):
                if patternCanPaint(chunk) { out += chunk; kept += 1 }
                out += "\n"
            }
        }
        return kept > 0 ? out : src
    }

    /// Whether any `@capture` in one pattern's text maps to a colored role —
    /// i.e. whether the pattern can ever contribute a visible hit.
    private static func patternCanPaint(_ chunk: String) -> Bool {
        var scalars = Substring(chunk).unicodeScalars[...]
        while let at = scalars.firstIndex(of: "@") {
            var j = scalars.index(after: at)
            var name = ""
            while j < scalars.endIndex {
                let c = scalars[j]
                if c == " " || c == "\n" || c == "\t" || c == "\r" || c == "(" || c == ")"
                    || c == "[" || c == "]" || c == ";" || c == "\"" { break }
                name.unicodeScalars.append(c)
                j = scalars.index(after: j)
            }
            if role(for: name) != nil { return true }
            scalars = scalars[j...]
        }
        return false
    }

    /// The semantic role for a tree-sitter capture (first dotted component), e.g.
    /// "function.method" → "function". Bare `variable`/`identifier` map to nil (default text),
    /// as in VS Code: nvim-style catch-alls like `(identifier) @variable` otherwise paint every
    /// identifier. Qualified captures (`@variable.builtin`, `@variable.parameter`) stay coloured;
    /// sigiled variables (`$VAR`, `--custom-prop`) are re-captured as `@property` instead.
    public static func role(for capture: String) -> String? {
        if capture == "variable" || capture == "identifier" { return nil }   // bare catch-alls
        // Checked before the first-component split: bare "namespace" stays a type-colored
        // module name, while the PREFIX of a qualified name recedes (PhpStorm-style).
        if capture == "namespace.prefix" { return "muted" }
        // `@plain` is this package's own: "this token is deliberately the plain foreground". Painting
        // is additive — nothing can un-paint an earlier hit — so overruling a grammar
        // that classified a token wrongly needs a color, not the absence of one (Kotlin
        // calls every import alias a `type_identifier`, whatever it renames).
        // NOT wired to nvim's `@none`, which the Dart/Dockerfile/Kotlin/Scala queries
        // put on string interpolations (`"$name"`, `${…}`): those patterns are colorless,
        // so `prunedQuerySource` drops them and interpolations stay string-colored. Giving
        // `@none` this role would flip all four languages at once — and because those
        // patterns sit AFTER the property/identifier ones, it would flatten `${a.size}`
        // to plain rather than highlight it as code.
        if capture == "plain" { return "plain" }
        switch capture.split(separator: ".").first.map(String.init) ?? capture {
        case "keyword", "conditional", "repeat", "include", "exception",
             "storageclass", "label", "tag":            return "keyword"
        case "string", "character", "escape":           return "string"
        case "comment", "spell":                        return "comment"
        case "number", "float":                         return "number"
        case "boolean", "constant":                     return "constant"
        case "type", "constructor", "namespace", "module", "class": return "type"
        case "function", "method":                      return "function"
        case "variable", "parameter":                   return "variable"
        case "property", "field", "member", "attribute", "annotation", "decorator":
            return "property"
        default:                                        return nil
        }
    }

    /// Maps a capture name to a theme color via its role.
    private static func color(for capture: String) -> NSColor? {
        switch role(for: capture) {
        case "keyword":            return HighlightTheme.colors.color(for: .keyword)
        case "string":             return HighlightTheme.colors.color(for: .string)
        case "comment":            return HighlightTheme.colors.color(for: .comment)
        case "number", "constant": return HighlightTheme.colors.color(for: .number)
        case "type":               return HighlightTheme.colors.color(for: .type)
        case "function":           return HighlightTheme.colors.color(for: .function)
        case "variable":           return HighlightTheme.colors.color(for: .variable)
        case "property":           return HighlightTheme.colors.color(for: .property)
        // Receded, not recolored: the theme's own foreground at reduced alpha keeps
        // the dimming correct on every palette, light or dark, with no new token role.
        case "muted":              return HighlightTheme.colors.foreground.withAlphaComponent(0.55)
        // The theme's own foreground: an explicit "this token is plain" paint, the
        // only way to overrule a grammar that classified a token wrongly.
        case "plain":              return HighlightTheme.colors.foreground
        default:                   return nil
        }
    }

    /// Number of ERROR nodes tree-sitter produced for `text` — a probe that judges highlight
    /// coverage must know when its own sample does not parse (captures vanish around errors).
    public static func parseErrorCount(in text: String, language: CodeLanguage.Language) -> Int {
        guard let g = grammar(for: language) else { return -1 }
        let parser = Parser()
        try? parser.setLanguage(g.language)
        guard let tree = parser.parse(text), let root = tree.rootNode else { return -1 }
        var count = 0
        func walk(_ node: Node) {
            if node.nodeType == "ERROR" { count += 1 }
            guard node.hasError else { return }   // only descend where an error lives
            for i in 0..<node.childCount { if let c = node.child(at: i) { walk(c) } }
        }
        walk(root)
        return count
    }

    /// Headless validation: prints every token → capture → role for the file at `path`, so
    /// highlighting can be checked across languages without opening the app.
    public static func dumpCaptures(path: String) {
        let url = URL(fileURLWithPath: path)
        let lang = CodeLanguage.Language.detect(for: url)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("!! cannot read \(path)"); return
        }
        guard let g = grammar(for: lang) else {
            print("!! no tree-sitter grammar for \(lang.displayName) (\(url.lastPathComponent))"); return
        }
        let ns = content as NSString
        print("== \(url.lastPathComponent)  [\(lang.displayName)] ==")
        MainActor.assumeIsolated {
            var winners: [String: (loc: Int, text: String, name: String, pattern: Int, lang: String)] = [:]
            collectWinners(g, source: content, ns: ns, offset: 0, lang: lang.displayName, depth: 0, into: &winners)
            for w in winners.values.sorted(by: { $0.loc < $1.loc }) {
                let role = Self.role(for: w.name) ?? "·default·"
                let tag = w.lang == lang.displayName ? "" : "   «\(w.lang)»"
                print("  \(w.text.padding(toLength: 20, withPad: " ", startingAt: 0))  @\(w.name.padding(toLength: 20, withPad: " ", startingAt: 0)) → \(role)\(tag)")
            }
        }
    }

    /// Collects the winning (highest-`patternIndex`) capture per token span,
    /// recursing into injections — the data behind `dumpCaptures`.
    @MainActor
    private static func collectWinners(_ g: Grammar, source: String, ns: NSString, offset: Int, lang: String, depth: Int,
                                       ranges: [NSRange]? = nil,
                                       into winners: inout [String: (loc: Int, text: String, name: String, pattern: Int, lang: String)]) {
        let tree: MutableTree?
        if let ranges {
            tree = combinedParse(g, ns: ns, ranges: ranges)
        } else {
            let parser = Parser()
            try? parser.setLanguage(g.language)
            tree = parser.parse(source)
        }
        guard let tree else { return }
        let cursor = g.highlights.execute(in: tree)
        let resolving = ResolvingQueryCursor(cursor: cursor)
        resolving.prepare(with: { r, _ in NSMaxRange(r) <= ns.length ? ns.substring(with: r) : nil })
        while let match = resolving.next() {
            for cap in match.captures {
                guard let name = cap.name, NSMaxRange(cap.range) <= ns.length else { continue }
                let text = ns.substring(with: cap.range).trimmed
                // Skip captures that span lines — a block/whole-file capture would drown the
                // dump — but KEEP long single-line tokens (printing truncates them anyway).
                // Must not cap by length: a dropped long token looks exactly like a missing
                // capture.
                guard !text.isEmpty, !text.contains("\n"), text.count <= 400 else { continue }
                let absLoc = offset + cap.range.location
                let key = "\(absLoc):\(cap.range.length)"
                if let ex = winners[key], ex.pattern >= cap.patternIndex { continue }
                winners[key] = (absLoc, text, name, cap.patternIndex, lang)
            }
        }
        guard depth < 3, let injQuery = g.injections else { return }
        for site in injectionSites(injQuery, tree: tree, ns: ns) {
            guard let sub = grammarForInjection(site.name) else { continue }
            collectWinners(sub, source: source, ns: ns, offset: offset,
                           lang: site.name, depth: depth + 1, ranges: site.ranges, into: &winners)
        }
    }
}

extension NSRange {
    /// The smallest range covering both `self` and `other` (`NSUnionRange`).
    func union(_ other: NSRange) -> NSRange { NSUnionRange(self, other) }
}
