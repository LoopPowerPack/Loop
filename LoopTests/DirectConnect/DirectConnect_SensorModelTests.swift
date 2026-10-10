//
//  DirectConnect_SensorModelTests.swift
//  LoopTests
//
//  Concept & design by Taylor Patterson. Coded & tested by Claude Code in October 2026.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import XCTest
@testable import Loop

final class DirectConnect_SensorModelTests: XCTestCase {
    func testTypeFromName() {
        XCTAssertEqual(DirectConnect_SensorType.from(peripheralName: "DXCMab"), .g7)
        XCTAssertEqual(DirectConnect_SensorType.from(peripheralName: "DX02cd"), .onePlus)
        XCTAssertEqual(DirectConnect_SensorType.from(peripheralName: "DX01ef"), .stelo)
        XCTAssertNil(DirectConnect_SensorType.from(peripheralName: "Dexcom12"))
    }

    func testSessionLengthPrefersReportedValue() {
        XCTAssertEqual(DirectConnect_SensorLifetime.knownSessionLength(reported: 1339200, type: .g7), 1339200)
        XCTAssertEqual(DirectConnect_SensorLifetime.knownSessionLength(reported: 907200, type: .g7), 907200)
        XCTAssertEqual(DirectConnect_SensorLifetime.knownSessionLength(reported: 907200, type: .stelo), 907200)
    }

    func testG7LengthIsUnknownUntilTheSensorReportsIt() {
        // G7 is sold as 10-day and 15-day; Loop does not guess.
        XCTAssertNil(DirectConnect_SensorLifetime.knownSessionLength(reported: nil, type: .g7))
        XCTAssertNil(DirectConnect_SensorLifetime.knownSessionLength(reported: 12345, type: .g7))
    }

    func testSingleLengthProductsAreKnownBeforeReporting() {
        XCTAssertEqual(DirectConnect_SensorLifetime.knownSessionLength(reported: nil, type: .stelo), 1339200)
        XCTAssertEqual(DirectConnect_SensorLifetime.knownSessionLength(reported: nil, type: .onePlus), 907200)
    }

    func testFollowedSensorIsMadeActive() {
        XCTAssertEqual(DirectConnect_shouldConnect(peripheralName: "DXCMab", followedName: "DXCMab", excludedName: nil, expectedType: .g7), .makeActive)
    }

    func testFollowedSensorMatchesFullDexcomName() {
        XCTAssertEqual(DirectConnect_shouldConnect(peripheralName: "Dexcomab", followedName: "DXCMab", excludedName: nil, expectedType: .g7), .makeActive)
        XCTAssertEqual(DirectConnect_shouldConnect(peripheralName: "Otherab", followedName: "DXCMab", excludedName: nil, expectedType: .g7), .ignore)
    }

    func testScanConnectsMatchingTypeOnly() {
        XCTAssertEqual(DirectConnect_shouldConnect(peripheralName: "DXCMab", followedName: nil, excludedName: nil, expectedType: .g7), .connect)
        XCTAssertEqual(DirectConnect_shouldConnect(peripheralName: "DX01ab", followedName: nil, excludedName: nil, expectedType: .g7), .ignore)
    }

    func testScanCanPairThePreviousSensorAgain() {
        // An old sensor is filtered by refusing the new code, not by name, so the same sensor
        // can be paired again from Pair New Sensor.
        XCTAssertEqual(DirectConnect_shouldConnect(peripheralName: "DXCMold", followedName: nil, excludedName: "DXCMold", expectedType: .g7), .connect)
    }

    func testIgnoresOtherFollowedNamesAndUnnamed() {
        XCTAssertEqual(DirectConnect_shouldConnect(peripheralName: "DXCMzz", followedName: "DXCMab", excludedName: nil, expectedType: .g7), .ignore)
        XCTAssertEqual(DirectConnect_shouldConnect(peripheralName: nil, followedName: nil, excludedName: nil, expectedType: .g7), .ignore)
    }
}
