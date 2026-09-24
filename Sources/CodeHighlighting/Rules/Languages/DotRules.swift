//
//  DotRules.swift
//  CodeHighlighting
//
//  The regex rule table for Graphviz DOT.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Graphviz DOT: `//`, `/* */` and `#` comments, the graph words, `->` / `--` edges,
/// `attr=value` pairs, quoted labels, numbers. Written 25 Sep 2026 (the sweep found two roles).
extension RuleTables {
    static let dot: [(String, TokenKind)] = [
        lineComment,
        blockComment,
        ("^\\s*#.*$", .comment),
        doubleQuoted,
        ("<[^>]*>", .string),
        keywords(["digraph", "graph", "subgraph", "node", "edge", "strict", "cluster"]),
        ("->|--", .type),
        ("\\b[A-Za-z_][\\w]*(?=\\s*=)", .attribute),
        ("\\b(rankdir|label|shape|style|color|fillcolor|fontname|fontsize|penwidth|arrowhead|dir|weight|constraint|splines|nodesep|ranksep|bgcolor|layout|compound|width|height)\\b", .attribute),
        ("#[0-9A-Fa-f]{6}\\b|\\b\\d+(\\.\\d+)?\\b", .number),
        ("\\b[A-Za-z_]\\w*(?=\\s*(\\[|->|--|;|$))", .variable),
    ]
}
