//
//  DirectConnect_StateTests.swift
//  LoopTests
//
//  Concept & design by Taylor Patterson. Coded & tested by Claude Code in October 2026.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import XCTest
@testable import Loop

final class DirectConnect_StateTests: XCTestCase {
    func testRawStateRoundTrip() {
        var s = DirectConnect_G7State()
        s.sensorID = "DXCMab"
        s.sensorType = .stelo
        s.pairingCode = "1234"
        s.previousSensorID = "DXCMzz"
        s.activatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        s.extendedVersion = DirectConnect_G7ExtendedVersion(data: Data(dcHex: "5200406f1400880e00010a04ff1100")!)
        s.latestReading = DirectConnect_G7GlucoseMessage(data: Data(dcHex: "4e00d507000009000001050061000601ffff0e")!)
        s.latestReadingTimestamp = Date(timeIntervalSince1970: 1_800_000_300)
        s.latestConnect = Date(timeIntervalSince1970: 1_800_000_310)
        s.uploadReadings = false
        s.battery = DirectConnect_G7BatteryStatus(data: Data(dcHex: "220020010b0106210000000001")!)
        s.batteryReadAt = Date(timeIntervalSince1970: 1_800_000_320)
        s.versionInfo = DirectConnect_G7VersionInfo(data: Data(dcHex: "4a00020301040a00000014000000010203040506")!)
        s.recentReadings = [100, 101]
        s.pairingFailure = "failure text"
        XCTAssertTrue(s.calibration.enqueue(glucose: 120, date: Date()))
        s.alarmState.lastFired["low"] = Date(timeIntervalSince1970: 1_800_000_100)
        XCTAssertEqual(DirectConnect_G7State(rawValue: s.rawValue), s)
    }

    func testEmptyRawStateUsesDefaults() {
        let s = DirectConnect_G7State(rawValue: [:])
        XCTAssertNil(s.sensorID)
        XCTAssertEqual(s.sensorType, .g7)
        XCTAssertTrue(s.uploadReadings)
        XCTAssertEqual(s.calibration, DirectConnect_CalibrationQueue())
        XCTAssertTrue(s.alarmState.lastFired.isEmpty)
    }

    func testSixIdenticalReadingsRule() {
        var s = DirectConnect_G7State()
        for _ in 0..<5 { XCTAssertFalse(s.recordReadingAndCheckStuck(110)) }
        XCTAssertTrue(s.recordReadingAndCheckStuck(110))
        XCTAssertFalse(s.recordReadingAndCheckStuck(111))
        XCTAssertEqual(s.recentReadings.count, 6)
    }

    func testSessionLengthComesFromTheSensor() {
        var s = DirectConnect_G7State()
        s.sensorType = .g7
        XCTAssertNil(s.knownSessionLength)
        s.extendedVersion = DirectConnect_G7ExtendedVersion(data: Data(dcHex: "5200406f1400880e00010a04ff1100")!)
        XCTAssertEqual(s.knownSessionLength, DirectConnect_SensorLifetime.fifteenDaySession)
        XCTAssertEqual(s.warmupDuration, 3720)
        s.extendedVersion = DirectConnect_G7ExtendedVersion(data: Data(dcHex: "5200c0d70d00540600020404ff0c00")!)
        XCTAssertEqual(s.knownSessionLength, DirectConnect_SensorLifetime.tenDaySession)
        XCTAssertEqual(s.warmupDuration, 1620)
    }

    func testEstimatedLengthIsOnlyForProgressDisplay() {
        let s = DirectConnect_G7State()
        XCTAssertNil(s.knownSessionLength)
        XCTAssertEqual(s.estimatedSessionLength, DirectConnect_SensorLifetime.tenDaySession)
    }
}
