//
//  CompletionTests.swift
//  Tests for CompletionProvider's pure ranking/scanning core: rank() tier order,
//  dedup, prefix rules, cap; bufferWords() charset, length bounds, and sorting.
//  Headless — no editor, no tree-sitter parse.
//

import XCTest
@testable import CodeHighlighting

final class CompletionTests: XCTestCase {

    private func item(_ text: String, kind: SymbolKind? = .function, detail: String? = nil) -> CompletionItem {
        CompletionItem(text: text, kind: kind, detail: detail)
    }

    // MARK: - rank

    func testPrefixMatchIsCaseInsensitive() {
        let out = CompletionProvider.rank(
            partial: "fo",
            fileSymbols: [item("Foobar"), item("food"), item("bar")],
            projectSymbols: [], bufferWords: [])
        XCTAssertEqual(out.map(\.text), ["Foobar", "food"])
    }

    func testTierOrderFileThenProjectThenBuffer() {
        let out = CompletionProvider.rank(
            partial: "a",
            fileSymbols: [item("alpha")],
            projectSymbols: [item("apex", detail: "x.swift")],
            bufferWords: ["around"])
        XCTAssertEqual(out.map(\.text), ["alpha", "apex", "around"])
    }

    func testDedupPrefersHigherTier() {
        // "shared" appears in all three tiers; only the file-symbol copy (with
        // its kind) survives, at rank 0.
        let out = CompletionProvider.rank(
            partial: "sh",
            fileSymbols: [item("shared", kind: .method)],
            projectSymbols: [item("shared", kind: .function, detail: "p.swift")],
            bufferWords: ["shared"])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].kind, .method)
        XCTAssertNil(out[0].detail)
    }

    func testDropsCandidateIdenticalToPartial() {
        // Completing "count" to "count" is noise; a longer match survives.
        let out = CompletionProvider.rank(
            partial: "count",
            fileSymbols: [item("count"), item("counter")],
            projectSymbols: [], bufferWords: [])
        XCTAssertEqual(out.map(\.text), ["counter"])
    }

    func testCapLimitsResults() {
        let syms = (0..<10).map { item("item\($0)") }
        let out = CompletionProvider.rank(
            partial: "item", fileSymbols: syms, projectSymbols: [], bufferWords: [], cap: 3)
        XCTAssertEqual(out.count, 3)
    }

    func testEmptyPartialYieldsNothing() {
        XCTAssertTrue(CompletionProvider.rank(
            partial: "", fileSymbols: [item("x")], projectSymbols: [], bufferWords: []).isEmpty)
    }

    func testNonMatchingPrefixExcluded() {
        let out = CompletionProvider.rank(
            partial: "zz", fileSymbols: [item("alpha")], projectSymbols: [], bufferWords: ["beta"])
        XCTAssertTrue(out.isEmpty)
    }

    // MARK: - bufferWords

    func testBufferWordsExtractsIdentifiers() {
        let words = CompletionProvider.bufferWords(in: "let userName = fetchData(userName)")
        XCTAssertEqual(words, ["fetchData", "let", "userName"])   // sorted, unique
    }

    func testBufferWordsSkipsShortWords() {
        // "a" and "id" are below minWordLength (3).
        let words = CompletionProvider.bufferWords(in: "a id abc")
        XCTAssertEqual(words, ["abc"])
    }

    func testBufferWordsRejectsDigitLedTokens() {
        // "3rd" starts with a digit → not identifier-shaped; "_x9" is fine.
        let words = CompletionProvider.bufferWords(in: "3rd value _x9 100")
        XCTAssertEqual(words, ["_x9", "value"])
    }

    func testBufferWordsAllowsUnderscoreAndDollar() {
        let words = CompletionProvider.bufferWords(in: "$scope _private mixed_Case")
        XCTAssertEqual(words, ["$scope", "_private", "mixed_Case"])
    }

    func testBufferWordsCaseInsensitiveSortStableTiebreak() {
        let words = CompletionProvider.bufferWords(in: "Beta alpha Alpha beta")
        // caseInsensitive groups Alpha/alpha then Beta/beta; case-sensitive
        // tiebreak puts uppercase first.
        XCTAssertEqual(words, ["Alpha", "alpha", "Beta", "beta"])
    }

    func testBufferWordsEmptyForNoIdentifiers() {
        XCTAssertTrue(CompletionProvider.bufferWords(in: "!!! ... ,,,").isEmpty)
    }

    // MARK: - Language built-ins tier

    func testPHPBuiltinsLoadAndPrefixMatch() {
        let builtins = LanguageBuiltins.completions(for: .php)
        XCTAssertFalse(builtins.isEmpty, "php.txt should load")
        XCTAssertTrue(builtins.contains { $0.text == "array_map" })
        XCTAssertTrue(builtins.contains { $0.text == "preg_match" })
        // Ranked into completion for a partial.
        let out = CompletionProvider.rank(partial: "array_", fileSymbols: [], projectSymbols: [],
                                          bufferWords: [], builtins: builtins)
        XCTAssertTrue(out.contains { $0.text == "array_map" })
        XCTAssertTrue(out.contains { $0.text == "array_filter" })
    }

    func testTypeScriptIsASupersetOfJavaScript() {
        // TypeScript loads javascript.txt then typescript.txt: every JS identifier is still
        // there, plus the TS-only ones.
        let js = Set(LanguageBuiltins.completions(for: .javascript).map(\.text))
        let ts = Set(LanguageBuiltins.completions(for: .typescript).map(\.text))
        XCTAssertTrue(js.isSubset(of: ts))
        XCTAssertTrue(ts.contains("Record") && !js.contains("Record"))
    }

    func testPythonBuiltins() {
        let py = LanguageBuiltins.completions(for: .python)
        XCTAssertTrue(py.contains { $0.text == "enumerate" })
        XCTAssertTrue(py.contains { $0.text == "len" })
    }

    func testUnsupportedLanguageHasNoBuiltins() {
        XCTAssertTrue(LanguageBuiltins.completions(for: .plainText).isEmpty)
    }

    func testBuiltinSignatureParsedIntoDetail() {
        // A `name<TAB>signature` line puts the signature in the item's detail
        // (shown in the popup); only the name is inserted (item.text).
        let php = LanguageBuiltins.completions(for: .php)
        let arrayMap = php.first { $0.text == "array_map" }
        XCTAssertNotNil(arrayMap)
        XCTAssertEqual(arrayMap?.detail, "array_map(callable $callback, array ...$arrays): array")
        // A bare-name line has no detail.
        let isString = php.first { $0.text == "is_string" }
        XCTAssertNotNil(isString)
        XCTAssertEqual(isString?.detail, "is_string(mixed $value): bool")
    }

    func testBuiltinsRankBelowProjectSymbolsAboveBufferWords() {
        // A file symbol / project symbol named the same as a builtin wins; a bare
        // buffer word of the same name loses to the builtin.
        let out = CompletionProvider.rank(
            partial: "ma",
            fileSymbols: [], projectSymbols: [item("mainHandler", kind: .function)],
            bufferWords: ["maybe"],
            builtins: [item("map", kind: .function)])
        // Order: project (mainHandler) → builtin (map) → buffer (maybe).
        XCTAssertEqual(out.map(\.text), ["mainHandler", "map", "maybe"])
    }

    // MARK: - symbolsProvider caching

    func testEmptySymbolsProviderResultIsNotCached() {
        // The editor's provider yields [] while the session's warm-up parse is
        // still running; caching that would pin the file-symbol tier empty for
        // the unedited buffer (only noteEdit clears the cache).
        let provider = CompletionProvider()
        var symbols: [Symbol] = []
        provider.symbolsProvider = { symbols }
        XCTAssertTrue(provider.completions(for: "qq", text: "", language: .plainText).isEmpty)

        symbols = [Symbol(name: "qqAlpha", kind: .function,
                          range: NSRange(location: 0, length: 7), line: 1)]
        let out = provider.completions(for: "qq", text: "", language: .plainText)
        XCTAssertEqual(out.map(\.text), ["qqAlpha"],
                       "warm-up's empty tier must not stick without an edit")
    }

    func testNonEmptySymbolsProviderResultIsCached() {
        var calls = 0
        let provider = CompletionProvider()
        provider.symbolsProvider = {
            calls += 1
            return [Symbol(name: "qqAlpha", kind: .function,
                           range: NSRange(location: 0, length: 7), line: 1)]
        }
        _ = provider.completions(for: "qq", text: "", language: .plainText)
        _ = provider.completions(for: "qq", text: "", language: .plainText)
        XCTAssertEqual(calls, 1, "a non-empty tier is cached until noteEdit")
        provider.noteEdit()
        _ = provider.completions(for: "qq", text: "", language: .plainText)
        XCTAssertEqual(calls, 2)
    }

    func testPHPLanguageConstructsHaveSignatures() {
        // unset/isset/empty/echo/… are constructs, not functions; the hover and completion
        // paths look them up in the same builtin list, so they must carry a signature.
        let items = LanguageBuiltins.completions(for: .php)
        for name in ["unset", "isset", "empty", "echo", "print", "list", "array", "exit", "require_once"] {
            let item = items.first { $0.text == name }
            XCTAssertNotNil(item, name)
            XCTAssertFalse(item?.detail?.isEmpty ?? true, "\(name) has a signature")
        }
    }

    func testTypeScriptOverridesJavaScriptEntry() {
        // typescript.txt is loaded after javascript.txt and wins on the same identifier.
        let js = LanguageBuiltins.completions(for: .javascript).first { $0.text == "unknown" }
        let ts = LanguageBuiltins.completions(for: .typescript).first { $0.text == "unknown" }
        XCTAssertNil(js?.detail)
        XCTAssertTrue(ts?.detail?.contains("top type") ?? false)
        XCTAssertEqual(LanguageBuiltins.completions(for: .typescript).filter { $0.text == "unknown" }.count, 1)
    }

    func testCommonBuiltinsHaveSignaturesInEveryLanguage() {
        // Hover shows `.detail`; a bare entry completes but never hovers. Keywords stay bare on
        // purpose (no "Built-in function" card on `if`), everything else must carry a signature.
        let samples: [(String, [CompletionItem], [String])] = [
            ("swift", LanguageBuiltins.completions(for: .swift), ["print", "map", "String", "Task", "count", "DispatchQueue"]),
            ("python", LanguageBuiltins.completions(for: .python), ["defaultdict", "split", "os", "Path", "startswith", "reduce"]),
            ("javascript", LanguageBuiltins.completions(for: .javascript), ["console", "isArray", "structuredClone", "Promise", "localStorage", "PI"]),
            ("typescript", LanguageBuiltins.completions(for: .typescript), ["console", "Record", "Partial", "unknown", "Awaited"]),
            ("go", LanguageBuiltins.completions(for: .go), ["append", "Println", "Errorf", "Mutex", "error"]),
            ("rust", LanguageBuiltins.completions(for: .rust), ["println", "Vec", "unwrap", "collect", "Arc"]),
            ("ruby", LanguageBuiltins.completions(for: .ruby), ["puts", "each", "map", "attr_accessor", "Hash"]),
            ("java", LanguageBuiltins.completions(for: .java), ["println", "ArrayList", "stream", "Optional", "Collectors"]),
            ("kotlin", LanguageBuiltins.completions(for: .kotlin), ["listOf", "let", "launch", "joinToString", "Flow"]),
            ("csharp", LanguageBuiltins.completions(for: .csharp), ["WriteLine", "Where", "Task", "Dictionary", "TryParse"]),
            ("c", LanguageBuiltins.completions(for: .c), ["printf", "malloc", "strlen", "size_t", "qsort"]),
            ("cpp", LanguageBuiltins.completions(for: .cpp), ["printf", "vector", "unique_ptr", "cout", "ranges"]),
            ("bash", LanguageBuiltins.completions(for: .bash), ["echo", "read", "grep", "set", "BASH_SOURCE"]),
            ("dart", LanguageBuiltins.completions(for: .dart), ["print", "Future", "setState", "where", "jsonDecode"]),
            ("lua", LanguageBuiltins.completions(for: .lua), ["print", "pairs", "setmetatable", "gsub", "pcall"]),
            ("sql", LanguageBuiltins.completions(for: .sql), ["SELECT", "JOIN", "COALESCE", "OVER", "JSONB"]),
            ("scala", LanguageBuiltins.completions(for: .scala), ["println", "Option", "foldLeft", "Future", "mkString"]),
            ("elixir", LanguageBuiltins.completions(for: .elixir), ["puts", "Enum", "GenServer", "put", "|>"]),
            ("perl", LanguageBuiltins.completions(for: .perl), ["print", "chomp", "open", "@_", "Data::Dumper"]),
            ("objectivec", LanguageBuiltins.completions(for: .objectivec), ["printf", "NSLog", "NSString", "dispatch_async", "NSMakeRange"]),
            ("css", LanguageBuiltins.completions(for: .css), ["display", "grid-template-columns", "@media", "var", ":has"]),
            ("html", LanguageBuiltins.completions(for: .html), ["div", "input", "aria-label", "loading", "dialog"]),
            ("zig", LanguageBuiltins.completions(for: .zig), ["@import", "ArrayList", "Allocator", "print", "usize"]),
            ("haskell", LanguageBuiltins.completions(for: .haskell), ["putStrLn", "foldr", "Maybe", "fmap", "Monad"]),
            ("r", LanguageBuiltins.completions(for: .r), ["data.frame", "lapply", "ggplot", "mutate", "%>%"]),
            ("powershell", LanguageBuiltins.completions(for: .powershell), ["Write-Host", "Get-ChildItem", "Where-Object", "$PSScriptRoot", "-match"]),
        ]
        for (language, items, names) in samples {
            for name in names {
                let item = items.first { $0.text == name }
                XCTAssertNotNil(item, "\(language) \(name)")
                XCTAssertFalse(item?.detail?.isEmpty ?? true, "\(language) \(name) has a signature")
            }
        }
    }
}
