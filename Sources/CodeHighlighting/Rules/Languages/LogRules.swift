//
//  LogRules.swift
//  CodeHighlighting
//
//  The regex rule table for log files.
//
//  Created by David Sherlock on 9/25/26.
//

import Foundation

/// Log files: timestamps, the levels (errors in the removed tint, successes in the added one),
/// `[thread]` tags, dotted class names, stack frames dimmed, URLs, durations, hex ids.
/// Written 25 Sep 2026 (the sweep found it flat).
extension RuleTables {
    static let log: [(String, TokenKind)] = [
        ("^\\s+at [\\w.$<>]+\\(.*\\)\\s*$", .comment),
        ("^\\s*(Caused by|\\.\\.\\. \\d+ more).*$", .comment),
        doubleQuoted,
        ("\\b\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}([.,]\\d+)?(Z|[+-]\\d{2}:?\\d{2})?\\b", .number),
        ("\\b\\d{2}:\\d{2}:\\d{2}([.,]\\d+)?\\b", .number),
        ("\\b(ERROR|ERR|FATAL|CRITICAL|CRIT|SEVERE|PANIC|EMERG|ALERT|FAILED|FAILURE|FAIL)\\b", .removed),
        ("\\b(WARN|WARNING|NOTICE)\\b", .keyword),
        ("\\b(TRACE|DEBUG|INFO|VERBOSE|FINE|FINER|FINEST)\\b", .type),
        ("\\b(SUCCESS|SUCCEEDED|OK|PASS|PASSED|DONE|COMPLETED?)\\b", .added),
        ("\\b\\w+(Exception|Error)\\b", .removed),
        ("\\[[^\\]]{1,60}\\]", .property),
        ("\\b[a-z]+(\\.[a-zA-Z_$][\\w$]*){2,}\\b", .function),
        ("\\bhttps?://\\S+", .string),
        ("\\b0x[0-9a-fA-F]+\\b|\\b[0-9a-f]{8,}\\b|\\b\\d+(\\.\\d+)?\\s?(ms|s|m|h|KB|MB|GB|%)\\b|#\\d+\\b", .number),
    ]
}
