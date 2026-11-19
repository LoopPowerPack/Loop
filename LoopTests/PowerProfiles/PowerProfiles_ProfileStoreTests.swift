//
//  PowerProfiles_ProfileStoreTests.swift
//  LoopTests
//
//  Concept & design by Taylor Patterson. Coded & tested by Claude Code in November 2026.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import XCTest
import LoopKit
import LoopKitUI
@testable import Loop

final class PowerProfiles_ProfileStoreTests: XCTestCase {

    private var directory: URL!
    private var store: PowerProfiles_ProfileStore!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = PowerProfiles_ProfileStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSanitizeMatchesProfiles() {
        XCTAssertEqual(PowerProfiles_ProfileStore.sanitize("Run.ning<1"), "Run_ning_1")
        XCTAssertEqual(PowerProfiles_ProfileStore.sanitize(String(repeating: "a", count: 40)).count, 32)
    }

    func testCreateNewWritesProfilesJSON() throws {
        let fileName = try store.createNew(PowerProfiles_TestData.values(name: "Running"), now: now)
        XCTAssertTrue(fileName.hasSuffix(".json"))
        let data = try XCTUnwrap(store.data(fileName: fileName))
        let profile = try JSONDecoder().decode(PowerProfiles_ProfileValues.self, from: data)
        XCTAssertEqual(profile.name, "Running")
        XCTAssertEqual(profile.sortOrder, -1)
        XCTAssertNoThrow(try JSONDecoder().decode(Profile.self, from: data))
    }

    func testCreateNewRefusesExistingName() throws {
        let fileName = try store.createNew(PowerProfiles_TestData.values(name: "Running"), now: now)
        let original = try XCTUnwrap(store.data(fileName: fileName))
        XCTAssertThrowsError(try store.createNew(PowerProfiles_TestData.values(name: "Running", carbRatios: [20]),
                                                 now: now.addingTimeInterval(60))) {
            XCTAssertEqual($0 as? PowerProfiles_StoreError, .nameExists("Running"))
        }
        XCTAssertEqual(store.data(fileName: fileName), original)
        XCTAssertEqual(store.loadAll().count, 1)
    }

    func testCreateNewRefusesEmptyName() {
        XCTAssertThrowsError(try store.createNew(PowerProfiles_TestData.values(name: "  "), now: now)) {
            XCTAssertEqual($0 as? PowerProfiles_StoreError, .emptyName)
        }
    }

    func testCreateNewPicksFreeFileNameInSameSecond() throws {
        let first = try store.createNew(PowerProfiles_TestData.values(name: "A"), now: now)
        let second = try store.createNew(PowerProfiles_TestData.values(name: "B"), now: now)
        XCTAssertNotEqual(first, second)
    }

    func testOverwriteKeepsFileName() throws {
        let fileName = try store.createNew(PowerProfiles_TestData.values(name: "Running"), now: now)
        try store.overwrite(PowerProfiles_TestData.values(name: "Running", carbRatios: [12]), fileName: fileName)
        XCTAssertEqual(store.loadAll().map(\.fileName), [fileName])
        XCTAssertEqual(store.loadAll().first?.values.carbRatioSchedule.items.first?.value, 12)
    }

    func testOverwriteMissingFileThrows() {
        XCTAssertThrowsError(try store.overwrite(PowerProfiles_TestData.values(), fileName: "missing.json")) {
            XCTAssertEqual($0 as? PowerProfiles_StoreError, .notFound("missing.json"))
        }
    }

    func testRestoreNilDeletes() throws {
        let fileName = try store.createNew(PowerProfiles_TestData.values(name: "Running"), now: now)
        try store.restore(fileName: fileName, data: nil)
        XCTAssertNil(store.data(fileName: fileName))
    }

    func testRestoreDataPutsBackBytes() throws {
        let fileName = try store.createNew(PowerProfiles_TestData.values(name: "Running"), now: now)
        let original = try XCTUnwrap(store.data(fileName: fileName))
        try store.overwrite(PowerProfiles_TestData.values(name: "Running", carbRatios: [12]), fileName: fileName)
        try store.restore(fileName: fileName, data: original)
        XCTAssertEqual(store.data(fileName: fileName), original)
    }

    func testLoadAllSkipsUnreadableFiles() throws {
        _ = try store.createNew(PowerProfiles_TestData.values(name: "Good"), now: now)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("bad.json"))
        XCTAssertEqual(store.loadAll().map(\.values.name), ["Good"])
    }
}
