//
//  XQueryRules.swift
//  CodeHighlighting
//
//  The regex rule table for XQuery.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// XQuery: `(: … :)` comments, `$variables`, the FLWOR and declaration words, prefixed
/// names (`xs:decimal`, `fn:count`), embedded element constructors, `@attributes`.
/// Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let xquery: [(String, TokenKind)] = [
        ("\\(:[\\s\\S]*?:\\)", .comment),
        doubleQuotedPlain,
        singleQuotedPlain,
        ("\\$[\\w:.-]+", .variable),
        keywords(["xquery", "version", "encoding", "declare", "namespace", "default", "element", "attribute", "function", "variable", "option", "boundary-space", "base-uri", "construction", "ordering", "copy-namespaces", "module", "import", "schema", "at", "external", "let", "for", "in", "where", "order", "by", "stable", "return", "if", "then", "else", "as", "every", "some", "satisfies", "typeswitch", "case", "ascending", "descending", "empty", "greatest", "least", "collation", "instance", "of", "treat", "castable", "cast", "to", "div", "idiv", "mod", "and", "or", "not", "eq", "ne", "lt", "le", "gt", "ge", "is", "union", "intersect", "except", "child", "descendant", "parent", "self", "ancestor", "text", "node", "document-node", "item", "count", "group", "window", "tumbling", "sliding", "try", "catch", "switch"]),
        ("\\b(xs|fn|math|map|array|local|ex):[\\w-]+", .type),
        ("</?[A-Za-z][\\w:-]*|/>|>", .keyword),
        ("@[\\w:-]+", .attribute),
        ("\\b[A-Za-z_][\\w-]*(?=\\s*\\()", .function),
        ("\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b", .number),
    ]
}
