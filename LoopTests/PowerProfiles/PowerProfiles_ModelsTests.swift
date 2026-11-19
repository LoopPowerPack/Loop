//
//  PowerProfiles_ModelsTests.swift
//  LoopTests
//
//  Concept & design by Taylor Patterson. Coded & tested by Claude Code in November 2026.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import XCTest
import HealthKit
import LoopKit
import LoopKitUI
@testable import Loop

final class PowerProfiles_ModelsTests: XCTestCase {

    func testSnapRoundsToNearestFiveAndClamps() {
        XCTAssertEqual(PowerProfiles_Slider.snap(7.4), 5)
        XCTAssertEqual(PowerProfiles_Slider.snap(7.5), 10)
        XCTAssertEqual(PowerProfiles_Slider.snap(-53), -50)
        XCTAssertEqual(PowerProfiles_Slider.snap(61), 50)
        XCTAssertEqual(PowerProfiles_Slider.range, -50...50)
        XCTAssertEqual(PowerProfiles_Slider.step, 5)
    }

    func testPercentNilWhenNotTicked() {
        var adjustment = PowerProfiles_Adjustment()
        adjustment.percents[.carbRatios] = 20
        XCTAssertNil(adjustment.percent(for: .carbRatios))
    }

    func testLockedUsesLockedPercentForEveryTickedSetting() {
        var adjustment = PowerProfiles_Adjustment()
        adjustment.ticked = [.basalRates, .carbRatios]
        adjustment.percents[.basalRates] = 5
        adjustment.isLocked = true
        adjustment.lockedPercent = -10
        XCTAssertEqual(adjustment.percent(for: .basalRates), -10)
        XCTAssertEqual(adjustment.percent(for: .carbRatios), -10)
        XCTAssertNil(adjustment.percent(for: .insulinSensitivity))
    }

    func testUnlockedUsesPerSettingPercent() {
        var adjustment = PowerProfiles_Adjustment()
        adjustment.ticked = [.basalRates, .carbRatios]
        adjustment.percents[.basalRates] = 15
        XCTAssertEqual(adjustment.percent(for: .basalRates), 15)
        XCTAssertEqual(adjustment.percent(for: .carbRatios), 0)
    }

    func testProfileValuesJSONMatchesProfilesKeys() throws {
        let data = try JSONEncoder().encode(PowerProfiles_TestData.values())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["name", "correctionRange", "carbRatioSchedule",
                                          "basalRateSchedule", "insulinSensitivitySchedule", "sortOrder"])
    }

    func testProfileValuesDecodesAsLoopKitProfile() throws {
        let data = try JSONEncoder().encode(PowerProfiles_TestData.values())
        XCTAssertNoThrow(try JSONDecoder().decode(Profile.self, from: data))
    }

    func testCurrentValuesNeedEverySchedule() {
        var settings = TherapySettings()
        XCTAssertNil(PowerProfiles_ProfileValues.current(name: "Now", from: settings))
        let values = PowerProfiles_TestData.values()
        settings.glucoseTargetRangeSchedule = values.correctionRange
        settings.carbRatioSchedule = values.carbRatioSchedule
        settings.basalRateSchedule = values.basalRateSchedule
        settings.insulinSensitivitySchedule = values.insulinSensitivitySchedule
        XCTAssertEqual(PowerProfiles_ProfileValues.current(name: "Now", from: settings)?.carbRatioSchedule,
                       values.carbRatioSchedule)
    }
}

/// Schedules shared by the PowerProfiles tests.
enum PowerProfiles_TestData {
    static func values(name: String = "Base",
                       carbRatios: [Double] = [10],
                       sensitivities: [Double] = [50],
                       basalRates: [Double] = [0.85],
                       targets: [(Double, Double)] = [(100, 110)]) -> PowerProfiles_ProfileValues {
        func items<T>(_ values: [T]) -> [RepeatingScheduleValue<T>] {
            values.enumerated().map { RepeatingScheduleValue(startTime: TimeInterval($0.offset * 3600), value: $0.element) }
        }
        let utc = TimeZone(identifier: "UTC")!
        return PowerProfiles_ProfileValues(
            name: name,
            correctionRange: GlucoseRangeSchedule(unit: .milligramsPerDeciliter,
                                                  dailyItems: items(targets.map { DoubleRange(minValue: $0.0, maxValue: $0.1) }),
                                                  timeZone: utc)!,
            carbRatioSchedule: CarbRatioSchedule(unit: PowerProfiles_Units.gramsPerUnit, dailyItems: items(carbRatios), timeZone: utc)!,
            basalRateSchedule: BasalRateSchedule(dailyItems: items(basalRates), timeZone: utc)!,
            // Loop stores insulin sensitivity schedules in the glucose unit only.
            insulinSensitivitySchedule: InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: items(sensitivities), timeZone: utc)!,
            sortOrder: 0)
    }

    /// Pump rates 0.05…30 U/h in 0.05 steps, as many pumps support.
    static let supportedBasalRates: [Double] = (1...600).map { Double($0) / 20 }
}
