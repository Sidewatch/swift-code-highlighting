# Swift Code Highlighting

Syntax highlighting for macOS `NSTextStorage`, with two backends behind one `CodeHighlighter` protocol: a tree-sitter engine driving 28 grammars, all vendored as local SwiftPM C targets under `Grammars/` (Bash, C, C++, C#, CSS, Dart, Dockerfile, Go, HTML, Java, JavaScript, JSON, Kotlin, Lua, Markdown — upstream's dual block + inline parsers, PHP, Python, Ruby, Rust, Scala, SQL, Swift, TOML, TSX, TypeScript, XML, YAML), queries shipped as `.bundle` resources (TSX shares the TypeScript bundle) — and a dependency-light regex fallback so **every** language [`CodeLanguage`](https://github.com/Sidewatch/swift-code-language) recognizes gets sensible coloring. Beyond coloring, the tree-sitter side powers symbol outlines, a project-wide definition index, hover docs, breadcrumbs, and structural selection. Depends on [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) and `CodeLanguage`; AppKit-only (`NSColor`/`NSTextStorage`).

- Module `CodeHighlighting` in `Sources/CodeHighlighting`; tests in `Tests`; `swift test` is the whole check.
- Swift 6 language mode, tools 6.2, macOS 14+, no dependencies unless the README says so.
- Part of the Sidewatch package family; every package follows the same layout and PR rules.

## Module map

- `Builtins/` — bundled resources: 
- `Completion/` — the engine: completion: CompletionProvider, LanguageBuiltins
- `Core/` — the engine: CustomLanguageDefinition, EmbeddedMarkupHighlighter, HighlightTheme, SyntaxHighlighter
- `Enums/` — enums with no behaviour beyond their cases and labels: TokenKind
- `Errors/` — every Error type, one per file: CustomLanguageDefinitionError
- `Outline/` — the engine: outline: MarkdownOutline, OutlineTree, StylesheetOutline
- `Protocols/` — protocols the module exposes: CodeHighlighter, TokenColorProviding
- `TreeSitter/` — the engine: treesitter: CodeIndenter, HighlightSession, ProjectSymbolIndex, ReceiverInference, SymbolIndex, SymbolVisibility, TreeSitterHighlighter

## Rules

@CONTRIBUTING.md
