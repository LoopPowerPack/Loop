//
//  PowerProfiles_UndoTests.swift
//  LoopTests
//
//  Concept & design by Taylor Patterson. Coded & tested by Claude Code in November 2026.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import XCTest
import LoopKit
@testable import Loop

/// Stands in for Loop's active settings: records what was activated.
private final class FakeLoader: PowerProfiles_ProfileLoading {
    var activeValues: PowerProfiles_ProfileValues?
    var activeProfileName: String?
    var activations: [PowerProfiles_ProfileValues] = []
    var failNext = false

    struct Failure: Error {}

    func activate(_ values: PowerProfiles_ProfileValues, completion: @escaping (Result<Void, Error>) -> Void) {
        if failNext {
            failNext = false
            completion(.failure(Failure()))
            return
        }
        activations.append(values)
        activeValues = values
        activeProfileName = values.name
        completion(.success(()))
    }
}

final class PowerProfiles_UndoTests: XCTestCase {

    private var root: URL!
    private var store: PowerProfiles_ProfileStore!
    private var loader: FakeLoader!
    private var notifications: NotificationCenter!
    private var adjustment = PowerProfiles_Adjustment(isLocked: true, lockedPercent: 10, percents: [:], ticked: [.carbRatios])

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = PowerProfiles_ProfileStore(directory: root.appendingPathComponent("LoopProfile"))
        loader = FakeLoader()
        loader.activeValues = PowerProfiles_TestData.values(name: "Base")
        loader.activeProfileName = "Base"
        notifications = NotificationCenter()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeCoordinator() -> PowerProfiles_Coordinator {
        PowerProfiles_Coordinator(store: store,
                                  undoStore: PowerProfiles_UndoStore(url: root.appendingPathComponent("undo.json")),
                                  loader: loader,
                                  notificationCenter: notifications)
    }

    private func wait(_ body: (@escaping (Result<Void, Error>) -> Void) -> Void) -> Result<Void, Error> {
        var result: Result<Void, Error>?
        body { result = $0 }
        return result!
    }

    func testSaveNewThenUndoDeletesFile() throws {
        let coordinator = makeCoordinator()
        let fileName = try coordinator.saveNew(PowerProfiles_TestData.values(name: "Running"), adjustment: adjustment)
        XCTAssertNotNil(store.data(fileName: fileName))
        XCTAssertTrue(coordinator.canUndo)
        XCTAssertNoThrow(try wait(coordinator.undo).get())
        XCTAssertNil(store.data(fileName: fileName))
        XCTAssertTrue(loader.activations.isEmpty, "saving a new profile never loads it")
    }

    func testSaveExistingThenUndoRestoresBytes() throws {
        let fileName = try store.createNew(PowerProfiles_TestData.values(name: "Running"))
        let original = store.data(fileName: fileName)
        let coordinator = makeCoordinator()
        try coordinator.saveExisting(PowerProfiles_TestData.values(name: "Running", carbRatios: [11]),
                                     fileName: fileName, adjustment: adjustment)
        XCTAssertNotEqual(store.data(fileName: fileName), original)
        XCTAssertNoThrow(try wait(coordinator.undo).get())
        XCTAssertEqual(store.data(fileName: fileName), original)
    }

    func testSaveAndLoadThenUndoReactivatesPrevious() throws {
        let coordinator = makeCoordinator()
        let previous = loader.activeValues
        XCTAssertNoThrow(try wait { coordinator.saveAndLoad(PowerProfiles_TestData.values(name: "Running", carbRatios: [11]),
                                                            fileName: nil, adjustment: adjustment, completion: $0) }.get())
        XCTAssertEqual(loader.activeProfileName, "Running")
        XCTAssertNoThrow(try wait(coordinator.undo).get())
        XCTAssertEqual(loader.activations.last, previous)
        XCTAssertEqual(loader.activeProfileName, "Base")
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func testFailedActivationRestoresFile() throws {
        let fileName = try store.createNew(PowerProfiles_TestData.values(name: "Running"))
        let original = store.data(fileName: fileName)
        loader.failNext = true
        let coordinator = makeCoordinator()
        let result = wait { coordinator.saveAndLoad(PowerProfiles_TestData.values(name: "Running", carbRatios: [11]),
                                                    fileName: fileName, adjustment: adjustment, completion: $0) }
        XCTAssertThrowsError(try result.get())
        XCTAssertEqual(store.data(fileName: fileName), original)
        XCTAssertFalse(coordinator.canUndo)
    }

    func testUndoSurvivesNewStoreInstance() throws {
        let fileName = try makeCoordinator().saveNew(PowerProfiles_TestData.values(name: "Running"), adjustment: adjustment)
        let afterRestart = makeCoordinator()
        XCTAssertTrue(afterRestart.canUndo)
        XCTAssertNoThrow(try wait(afterRestart.undo).get())
        XCTAssertNil(store.data(fileName: fileName))
    }

    func testSecondUndoDoesNothing() throws {
        let coordinator = makeCoordinator()
        _ = try coordinator.saveNew(PowerProfiles_TestData.values(name: "Running"), adjustment: adjustment)
        _ = try coordinator.saveNew(PowerProfiles_TestData.values(name: "Cycling"), adjustment: adjustment)
        XCTAssertNoThrow(try wait(coordinator.undo).get())
        XCTAssertFalse(coordinator.canUndo)
        XCTAssertNoThrow(try wait(coordinator.undo).get())
        XCTAssertEqual(store.loadAll().map(\.values.name), ["Running"], "only the last save is undone")
    }

    func testSavePostsNotification() throws {
        var received: Notification?
        let token = notifications.addObserver(forName: PowerProfiles_Coordinator.savedNotification, object: nil, queue: nil) {
            received = $0
        }
        defer { notifications.removeObserver(token) }
        _ = try makeCoordinator().saveNew(PowerProfiles_TestData.values(name: "Running"), adjustment: adjustment)
        XCTAssertEqual(received?.userInfo?["action"] as? String, "saveNew")
        XCTAssertEqual(received?.userInfo?["profileName"] as? String, "Running")
        XCTAssertEqual(received?.userInfo?["percents"] as? [String: Int], ["carbRatios": 10])
    }
}
