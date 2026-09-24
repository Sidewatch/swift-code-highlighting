//
//  EdgeQLRules.swift
//  CodeHighlighting
//
//  The regex rule table for EdgeQL.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// EdgeQL / ESDL: `#` comments, the schema and query words, the scalar types, `:=`, `.path`
/// lookups, `<casts>`, `123n` literals. Written 25 Sep 2026 (the sweep found two roles).
extension RuleTables {
    static let edgeql: [(String, TokenKind)] = [
        hashComment,
        singleQuoted,
        doubleQuoted,
        ("\\$\\$[\\s\\S]*?\\$\\$", .string),
        keywords(["module", "type", "abstract", "extending", "required", "optional", "multi", "single", "property", "link", "constraint", "exclusive", "index", "on", "default", "annotation", "using", "function", "returning", "scalar", "alias", "global", "select", "insert", "update", "delete", "filter", "order", "by", "limit", "offset", "with", "for", "in", "union", "detached", "introspect", "set", "unless", "conflict", "else", "if", "then", "group", "distinct", "exists", "not", "and", "or", "like", "ilike", "is", "asc", "desc", "empty", "first", "last", "true", "false", "start", "migration", "commit", "create", "alter", "drop", "to", "from", "as", "assert_single", "count", "len", "sum", "max", "min", "array_agg", "datetime_current", "random", "uuid_generate_v1mc"]),
        ("\\b(str|int16|int32|int64|float32|float64|bigint|decimal|bool|datetime|duration|uuid|json|bytes|array|tuple|range|anytype|cal::local_date|cal::local_datetime|std::\\w+)\\b", .type),
        ("<[\\w:]+>", .type),
        (":=|\\+=|-=|\\?\\?|\\?=|\\?!=|\\.<|\\.>|@", .keyword),
        ("\\.[a-zA-Z_]\\w*", .property),
        ("\\b\\d+(\\.\\d+)?n?\\b", .number),
        ("\\b[a-zA-Z_]\\w*(?=\\s*\\()", .function),
    ]
}
