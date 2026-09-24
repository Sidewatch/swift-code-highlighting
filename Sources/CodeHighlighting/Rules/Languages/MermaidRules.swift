//
//  MermaidRules.swift
//  CodeHighlighting
//
//  The regex rule table for Mermaid.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Mermaid: `%%` comments, the diagram and structure words, arrows, node labels in brackets,
/// `[*]` states, `: label` text. Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let mermaid: [(String, TokenKind)] = [
        ("%%.*$", .comment),
        doubleQuotedPlain,
        ("\\b(graph|flowchart|sequenceDiagram|classDiagram|stateDiagram(-v2)?|erDiagram|gantt|pie|journey|gitGraph|mindmap|timeline|quadrantChart|requirementDiagram|C4Context|sankey-beta|xychart-beta|block-beta)\\b", .keyword),
        keywords(["subgraph", "end", "direction", "title", "note", "right", "left", "of", "over", "participant", "actor", "activate", "deactivate", "loop", "alt", "else", "opt", "par", "and", "critical", "break", "rect", "section", "class", "state", "click", "style", "classDef", "linkStyle", "dateFormat", "axisFormat", "excludes", "todayMarker", "as", "TB", "TD", "BT", "RL", "LR", "commit", "branch", "checkout", "merge", "cherry-pick", "namespace", "accTitle", "accDescr", "showData"]),
        ("\\[\\*\\]", .keyword),
        ("<?-{1,3}>?|<?={1,3}>?|-\\.+->|--\\|>|\\.\\.>|\\*--|o--|<\\|--|--\\*|--o|-->>|--x|--\\)|:::|-\\.-", .type),
        ("\\[[^\\]]*\\]|\\([^)]*\\)|\\{[^}]*\\}|\\|[^|]*\\|", .string),
        (":\\s.*$", .string),
        ("^\\s*[A-Za-z_][\\w-]*", .variable),
        ("\\b\\d+(\\.\\d+)?%?\\b", .number),
    ]
}
