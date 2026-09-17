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

## Known non-issues (do not "fix" these again)

- `ResolvingQueryCursor` / `next()` deprecation warnings (3 sites): SwiftTreeSitter asks for `ResolvingQueryMatchSequence`. Deliberately left — the migration touches the hot query loop and wants its own measured change.
- `TreeSitterHighlighter.loadedCount` has no caller — public startup sanity check, kept.
- `CommentKeywords.regex` is a `try!` on a literal pattern — fine.
- Grammar queries cannot load under `swift test` (Bundle.main); paint is proven by `Sidewatch --dump-captures` / `--probe-highlight-coverage`.

## History

- 17 Sep 2026 — full audit (app + all 20 libraries), Claude with David.
