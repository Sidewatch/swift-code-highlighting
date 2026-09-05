//
//  CustomLanguageStoreTests.swift
//  CodeHighlightingTests
//
//  Tests for `CustomLanguageStore`: definitions load from a folder, filename claims beat
//  extension claims, and the first file wins a collision.
//
//  Created by David Sherlock on 9/5/26.
//

import XCTest
@testable import CodeHighlighting

/// Tests for `CustomLanguageStore`: definitions load from a folder, filename claims beat
/// extension claims, and the first file wins a collision.
final class CustomLanguageStoreTests: XCTestCase {
    private var folder: URL!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("langs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: folder) }
    private func write(_ name: String, _ json: String) throws { try json.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8) }

    func testClaimsByFilenameBeatExtensionAndFirstFileWins() throws {
        try write("a.json", #"{"name":"Alpha","extensions":["x","shared"]}"#)
        try write("b.json", #"{"name":"Beta","extensions":["shared"],"filenames":["Jenkinsfile"]}"#)
        let store = CustomLanguageStore(folder: folder)
        XCTAssertEqual(store.definitions.map(\.name), ["Alpha", "Beta"], "filename order")
        XCTAssertEqual(store.displayName(for: URL(fileURLWithPath: "/p/f.X")), "Alpha", "case-insensitive extension")
        XCTAssertEqual(store.displayName(for: URL(fileURLWithPath: "/p/f.shared")), "Alpha", "first claim wins")
        XCTAssertEqual(store.displayName(for: URL(fileURLWithPath: "/p/jenkinsfile")), "Beta", "exact filename, case-insensitive")
        XCTAssertNil(store.definition(for: URL(fileURLWithPath: "/p/f.txt")))
        XCTAssertNil(store.definition(for: URL(fileURLWithPath: "/p/noext")))
    }

    func testInvalidFilesAreSkippedAndReported() throws {
        try write("bad.json", #"{"extensions":["x"]}"#)
        try write("ok.json", #"{"name":"OK","extensions":["ok"]}"#)
        var skipped: [String] = []
        let store = CustomLanguageStore(folder: folder) { skipped.append($0) }
        XCTAssertEqual(store.definitions.map(\.name), ["OK"])
        XCTAssertEqual(skipped.count, 1)
        XCTAssertTrue(skipped[0].contains("bad.json"), skipped[0])
    }

    func testReloadIfChangedNoticesAnInPlaceSaveAndNothingElse() throws {
        try write("a.json", #"{"name":"Alpha","extensions":["x"]}"#)
        let store = CustomLanguageStore(folder: folder)
        XCTAssertFalse(store.reloadIfChanged(), "nothing moved")
        // Same size, later mtime: what an in-place save in another app looks like.
        let f = folder.appendingPathComponent("a.json")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 60)], ofItemAtPath: f.path)
        XCTAssertTrue(store.reloadIfChanged(), "an in-place save changes the file's mtime, not the folder's")
        XCTAssertFalse(store.reloadIfChanged())
        try write("a.json", #"{"name":"Alpha2","extensions":["x"]}"#)
        XCTAssertTrue(store.reloadIfChanged())
        XCTAssertEqual(store.displayName(for: URL(fileURLWithPath: "/p/f.x")), "Alpha2")
    }

    func testSeedOnlyWhenTheFolderIsMissing() throws {
        let example = folder.appendingPathComponent("example.json")
        try #"{"name":"Ex","extensions":["ex"]}"#.write(to: example, atomically: true, encoding: .utf8)
        let target = folder.appendingPathComponent("Languages")
        XCTAssertTrue(CustomLanguageStore.seedIfMissing(folder: target, example: example, as: "ex.json"))
        XCTAssertEqual(CustomLanguageStore(folder: target).definitions.map(\.name), ["Ex"])
        try FileManager.default.removeItem(at: target.appendingPathComponent("ex.json"))
        XCTAssertFalse(CustomLanguageStore.seedIfMissing(folder: target, example: example, as: "ex.json"), "a user who deleted the example but kept the folder is left alone")
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("ex.json").path))
    }
}
