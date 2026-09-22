# Audit log

Last full audit: **17 Sep 2026** — every source file covered by the MECHANICAL checks below (build warnings, tests,
dead-code and risk-pattern scans, docs drift); line-by-line logic review was targeted at the areas changed since
5 Sep 2026, not the whole tree. Nothing needs re-scanning unless it changed after that date. Add a dated line under *History* when you audit again, and keep the
*Known non-issues* list current so the next pass skips them.

## What a full audit checks

1. `swift build` warnings (none allowed except those listed under known non-issues) and `swift test` green.
2. Dead code: every `func`/type/property declared once and referenced nowhere in the app or the family
   (`grep -w` across `*.swift` AND non-Swift files — selectors and MCP names live in strings). Protocol
   requirements, `override`s, `@objc` actions and public API are NOT dead because Sidewatch does not call them.
3. Risky patterns: `Timer` without `invalidate`, `addObserver(forName:)` without `removeObserver`, `as!`, `try!`
   outside literal regexes, `fatalError` outside `init?(coder:)`, `print(` outside harnesses, TODO/FIXME left behind.
4. Docs drift: every name in CLAUDE.md's module map exists; AGENTS.md mirrors CLAUDE.md; README Usage matches the API.

## Result on 17 Sep 2026

- Build: clean. Tests: green.
- Fixed: `templateTagRegex`: dropped an unnecessary `nonisolated(unsafe)`.
- Fixed: Queries: revived dead patterns (later catch-alls outranked them) in Go, Python, Rust, PHP; Scala/Kotlin import lines; `@plain` role; `dumpCaptures` 30-char filter — see `65304fc` and the app's CLAUDE.md.

## Logic review — 18 Sep 2026 (every source and test file, line by line)

Fixed, each pinned by a test that fails against the old code:

- **A call was a breadcrumb scope.** `breadcrumbScopes` accepted any node whose type contains a
  definition word and that has a `name` field; Java's `method_invocation` and Lua's `function_call`
  satisfy both, so a caret inside a multi-line call's arguments read the CALLED method as an
  enclosing definition — `["A", "run", "call"]` for `other.call(1,\n 2)` — which grew a breadcrumb
  and pinned the call's line in sticky scroll. Node types containing `call` or `invocation` are
  skipped now (`call_signature` has no name field and was never a scope).
- **`colorFromHex("#+12345")` was a colour.** `UInt64(_:radix:)` accepts a leading sign; every
  character after the `#` must be a hex digit.
- **`url(//cdn…)` in SCSS/Less started a comment.** The stylesheet scanner exempted `//` only after a
  `:`; a protocol-relative unquoted URL follows `(`, and treating it as a comment swallowed the `;`
  that ended the `@import`, so the next rule's prelude began there and the outline listed
  `@import url( .a` (as a module) in place of `.a`.

Reviewed and sound: the grammar table and its lazy compile under a lock, `prunedQuerySource` /
`QuerySourceScanner`, `collectHits`' clip in source coordinates and the precedence windows,
`applyResolved`'s desired-run diff (zero writes on settled text — pinned by the
`didProcessEditingNotification` test), `injectionSites` / `mergeAscending` / `combinedParse`, the
template-tag masking, `HighlightSession` (the mirror kept in step by `noteEdit`, the desync drop, the
generation-stamped warm-up, the O(1) `currentTree` check), `ProjectSymbolIndex` (supersession by
generation, the mid-build replay, the one-batch rescan queue, the sorted-name cursor),
`SymbolQueries` and `visibleLanguages`, `SymbolOwners`, `CodeIndenter` (frozen interiors, the
closer-at-opener rule, the iterative walk), `ReceiverInference`, `EmbeddedMarkupHighlighter`'s region
scan and complement, `SyntaxHighlighter`'s one-pass string/comment merge, `HTTPRequestHighlighter`'s
state machine, `CustomLanguageDefinition`'s rule compile and friendly decode errors,
`CustomLanguageStore`'s per-file fingerprint, `MarkdownOutline` (fences, the 3-space cap, CRLF),
`StylesheetOutline` (banners, `//` banners, variables, the selector limit), `CompletionProvider`
(the empty-provider result deliberately not cached), `LanguageBuiltins` and `cardKind`. The module
map was missing `Rules/`, `Models/`, `Extensions/`, `SymbolKind`, `OutlineNode`, `StylesheetScanner`,
`SymbolOwners`, `SymbolQueries` and `CommentKeywords`; it lists every file now.

## Known non-issues (do not "fix" these again)

- `ResolvingQueryCursor` / `next()` deprecation warnings (3 sites): SwiftTreeSitter asks for `ResolvingQueryMatchSequence`. Deliberately left — the migration touches the hot query loop and wants its own measured change.
- `TreeSitterHighlighter.loadedCount` has no caller — public startup sanity check, kept.
- `CommentKeywords.regex` is a `try!` on a literal pattern — fine.
- Grammar queries cannot load under `swift test` (Bundle.main); paint is proven by `Sidewatch --dump-captures` / `--probe-highlight-coverage`.

## History

- 17 Sep 2026 — full audit (app + all 20 libraries), Claude with David.
- 18 Sep 2026 — logic review (every source and test file, line by line), Claude with David.
- 22 Sep 2026 — `Structure/YAMLStructure` added (the grammar already vendored for highlighting, read as ordered values); `YAMLStructureTests`.
