//
//  RuleTableCoverageTests.swift
//  CodeHighlightingTests
//
//  Every language that got a rule table on 25 Sep 2026 paints at least three roles on a real snippet.
//
//  Created by David Sherlock on 9/25/26.
//

import XCTest
import AppKit
import CodeLanguage
@testable import CodeHighlighting

/// A sweep of the corpus (25 Sep 2026) found 13 languages painting nothing, 4 painting one
/// role and 19 two; each got a table. This pins each on a snippet: at least three distinct
/// roles, so a table that falls back to an empty family again fails here. Colours are one per
/// role so the count is the roles', not the theme's.
@MainActor
final class RuleTableCoverageTests: XCTestCase {
    private struct DistinctColors: TokenColorProviding {
        let foreground = NSColor.black
        static let kinds: [TokenKind] = [.comment, .string, .keyword, .type, .number, .function, .attribute, .variable, .property, .added, .removed]
        func color(for kind: TokenKind) -> NSColor {
            let i = Self.kinds.firstIndex(of: kind) ?? 0
            return NSColor(hue: CGFloat(i + 1) / CGFloat(Self.kinds.count + 2), saturation: 1, brightness: 1, alpha: 1)
        }
    }

    private func roles(_ text: String, _ language: Language) -> Int {
        let storage = NSTextStorage(string: text, attributes: [.foregroundColor: NSColor.black])
        SyntaxHighlighter(language: language, colors: DistinctColors()).highlight(storage, in: NSRange(location: 0, length: storage.length))
        var seen = Set<String>()
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let c = value as? NSColor, c != .black { seen.insert(c.description) }
        }
        return seen.count
    }

    func testEveryNewTablePaintsAtLeastThreeRoles() {
        let snippets: [(Language, String)] = [
            (.erlang, "%% comment\n-module(sample).\nstart_link() -> gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).\nhandle_call({get, Key}, _From, State) -> {reply, maps:find(Key, State), State}.\n"),
            (.prolog, "% family\nparent(ada, bob).\nancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).\ncount(X, N) :- findall(D, ancestor(X, D), Ds), length(Ds, N).\n"),
            (.fortran, "! comment\nprogram sample\n  integer, parameter :: n = 3\n  real(8) :: total = 0.5d0\n  print '(A, F8.3)', 'Total: ', total\nend program sample\n"),
            (.cobol, "       IDENTIFICATION DIVISION.\n       PROGRAM-ID. PAYROLL.\n      * a comment line\n       01  WS-COUNT PIC 9(5) VALUE ZERO.\n           DISPLAY \"Employees: \" WS-COUNT.\n"),
            (.assembly, "; x86-64\nsection .data\n    msg db \"hello\", 10\n_start:\n    mov rax, 1\n    mov rdi, 0x2A\n    syscall\n"),
            (.llvm, "; sum\n@.fmt = private constant [4 x i8] c\"%d\\0A\\00\"\ndefine i64 @sum(i64 %n) {\nentry:\n  %acc = add nsw i64 %n, 1\n  ret i64 %acc\n}\n"),
            (.smalltalk, "\"a comment\"\nOrder >> describe\n    ^ '#', number printString, ' ', status\n| orders | orders := OrderedCollection new. orders add: 42.\n"),
            (.vbscript, "' comment\nOption Explicit\nDim count\ncount = 0\nIf count > 100 Then MsgBox \"Big\", vbInformation\nSet fso = CreateObject(\"Scripting.FileSystemObject\")\n"),
            (.xquery, "xquery version \"3.1\";\n(: a comment :)\ndeclare function ex:money($n as xs:decimal) as xs:string { format-number($n, \"#,##0.00\") };\nfor $o in $orders where $o/@number > 10 return <tr>{ $o }</tr>\n"),
            (.abap, "REPORT z_sample.\n* a comment\nDATA: lt_stock TYPE STANDARD TABLE OF ty_stock, lv_count TYPE i VALUE 0.\nLOOP AT lt_stock INTO DATA(ls_stock).\n  WRITE: / ls_stock-matnr.\nENDLOOP.\nMESSAGE |{ lv_count } rows| TYPE 'I'.\n"),
            (.mermaid, "%% comment\nstateDiagram-v2\n    [*] --> Pending\n    Pending --> Paid : payment ok\n    note right of Paid\n"),
            (.plantuml, "@startuml\n' comment\nactor Customer\nCustomer -> Web : Checkout\nalt payment ok\n  Pay --> API : paid\nend\n@enduml\n"),
            (.log, "2026-09-24 09:15:02.114 INFO  [main] inventory.Server - Starting on port 8080\n2026-09-24 09:16:12.003 ERROR [http-4] inventory.Payments - Charge failed: gateway timeout\n\tat inventory.Payments.charge(Payments.java:71)\n"),
            (.asciidoc, "= Deployment Guide\n:toc:\n\n== Overview\n\nThis covers *production* deploys of the `api` service. See <<rollback>>.\n\n[source,bash]\n----\ndocker build .\n----\n"),
            (.restructuredtext, "Inventory service\n=================\n\n.. contents:: On this page\n\nThe **inventory service** keeps ``stock``. See `the guide`_.\n\n.. _the guide: https://example.com\n"),
            (.textile, "h1. Inventory\n\nThe *inventory service* keeps _stock_ and answers @GET /orders@.\n\n* item one\n\"docs\":https://example.com\n"),
            (.gitattributes, "# line endings\n* text=auto eol=lf\n*.png binary\n*.mp4 filter=lfs diff=lfs merge=lfs -text\n"),
            (.json5, "// JSON5\n{ name: 'inventory', replicas: 3, timeoutMs: 0x7530, ratio: .75, motd: \"Welcome\", features: ['search',], }\n"),
            (.hjson, "{\n  # Hjson\n  name: inventory-api\n  replicas: 3\n  motd: '''multi\n  line'''\n  ssl: true\n}\n"),
            (.nix, "{\n  # comment\n  description = \"Inventory\";\n  outputs = { self, nixpkgs }: let pkgs = import nixpkgs { }; in { packages.default = pkgs.stdenv.mkDerivation { pname = \"inventory\"; version = \"1.4.0\"; }; };\n}\n"),
            (.pug, "//- comment\ndoctype html\nhtml(lang=\"en\")\n  head\n    title= `${user.name}`\n  body\n    h1.title Orders for #{user.name}\n    if orders.length === 0\n      p.muted No orders yet.\n"),
            (.haml, "-# comment\n%html{lang: \"en\"}\n  %body\n    %h1= t(\".title\")\n    - if @orders.empty?\n      %p.muted No orders\n"),
            (.slim, "/ comment\ndoctype html\nhtml lang=\"en\"\n  body\n    h1 = t(\".title\")\n    - if @orders.empty?\n      p.muted = t(\".empty\")\n"),
            (.bibtex, "% refs\n@article{knuth1984,\n  author = {Donald E. Knuth},\n  title = \"Literate Programming\",\n  year = {1984}\n}\n"),
            (.dot, "// pipeline\ndigraph pipeline {\n    rankdir = LR;\n    lint [label = \"Lint\", shape = box];\n    lint -> test -> build;\n}\n"),
            (.edgeql, "# schema\nmodule default {\n  type Person { required name: str; joined: datetime; }\n}\nselect Person { name } filter .name = 'Ada' limit 10;\n"),
            (.gomod, "module github.com/example/inventory\n\ngo 1.23\n\nrequire (\n\tgithub.com/jackc/pgx/v5 v5.7.1 // indirect\n)\nreplace github.com/example/shared => ../shared\n"),
            (.manifest, "Manifest-Version: 1.0\nMain-Class: com.example.inventory.Application\nClass-Path: lib/postgresql-42.7.4.jar\n"),
            (.meson, "# build\nproject('inventory', 'c', version : '1.4.0')\nsqlite = dependency('sqlite3', version : '>=3.40')\nif get_option('export')\n  message('on')\nendif\n"),
            (.quarto, "---\ntitle: \"Weekly\"\n---\n\n## Summary\n\nRevenue `r sum(paid$total)`.\n\n```{r}\n#| label: load\norders <- read.csv(\"orders.csv\")\n```\n"),
            (.strings, "/* Localizable */\n\"orders.title\" = \"Orders for %@\";\n\"orders.count\" = \"%d orders\\n\";\n"),
            (.texinfo, "@c a comment\n@node Top\n@chapter Endpoints\nThe @strong{inventory service} keeps @emph{stock}.\n"),
            (.jinja, "{# comment #}\n{% for host in backends %}\n    server {{ hostvars[host]['ansible_host'] }}:{{ api_port }} weight={{ loop.first and 2 or 1 }};\n{% endfor %}\n<div class=\"x\">{{ extra | indent(8) }}</div>\n"),
        ]
        for (language, snippet) in snippets {
            XCTAssertGreaterThanOrEqual(roles(snippet, language), 3, "\(language.rawValue) paints too few roles")
        }
    }
}
