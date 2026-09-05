//
//  RuleTableSnapshotTests.swift
//  CodeHighlightingTests
//
//  Every regex rule table, frozen: the tables are about to be restructured into one file per
//  language built from shared rule builders, and this pins that the (pattern, kind) pairs come
//  out byte-identical.
//
//  Created by David Sherlock on 9/5/26.
//

import XCTest
import CodeLanguage
@testable import CodeHighlighting

/// Every regex rule table, frozen: the tables are about to be restructured into one file per
/// language built from shared rule builders, and this pins that the (pattern, kind) pairs come
/// out byte-identical. Record with `RECORD_RULE_TABLES=1 swift test --filter RuleTableSnapshot`.
final class RuleTableSnapshotTests: XCTestCase {
    private var fixture: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/rule-tables.json")
    }

    private func snapshot() -> [String: [[String]]] {
        var out: [String: [[String]]] = [:]
        for lang in Language.allCases {
            out["lang:\(lang.rawValue)"] = RuleTables.table(for: lang).map { [$0.0, "\($0.1)"] }
        }
        for family in HighlightFamily.allCases {
            out["family:\(family)"] = RuleTables.table(for: family).map { [$0.0, "\($0.1)"] }
        }
        return out
    }

    func testRuleTablesMatchTheRecordedSnapshot() throws {
        let now = snapshot()
        if ProcessInfo.processInfo.environment["RECORD_RULE_TABLES"] == "1" {
            let data = try JSONSerialization.data(withJSONObject: now, options: [.sortedKeys, .prettyPrinted])
            try data.write(to: fixture)
            print("recorded \(now.count) tables to \(fixture.path)")
            return
        }
        let recorded = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as! [String: [[String]]]
        XCTAssertEqual(now.count, recorded.count)
        for (key, rules) in recorded {
            XCTAssertEqual(now[key], rules, key)
        }
    }
}
