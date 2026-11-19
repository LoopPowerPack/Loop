//
//  PowerProfiles_ScalerTests.swift
//  LoopTests
//
//  Concept & design by Taylor Patterson. Coded & tested by Claude Code in November 2026.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import XCTest
import HealthKit
import LoopKit
@testable import Loop

final class PowerProfiles_ScalerTests: XCTestCase {

    private let rates = PowerProfiles_TestData.supportedBasalRates

    private func adjustment(_ setting: PowerProfiles_Setting, _ percent: Int) -> PowerProfiles_Adjustment {
        var adjustment = PowerProfiles_Adjustment()
        adjustment.ticked = [setting]
        adjustment.percents[setting] = percent
        return adjustment
    }

    private func scaled(_ values: PowerProfiles_ProfileValues, _ setting: PowerProfiles_Setting, _ percent: Int) -> PowerProfiles_ProfileValues {
        PowerProfiles_Scaler.scale(values, by: adjustment(setting, percent), supportedBasalRates: rates)
    }

    func testPlusTwentyMultipliesByOnePointTwo() {
        let after = scaled(PowerProfiles_TestData.values(carbRatios: [10]), .carbRatios, 20)
        XCTAssertEqual(after.carbRatioSchedule.items[0].value, 12.0, accuracy: 1e-9)
    }

    func testMinusTenMultipliesByNinetyPercent() {
        let after = scaled(PowerProfiles_TestData.values(sensitivities: [50]), .insulinSensitivity, -10)
        XCTAssertEqual(after.insulinSensitivitySchedule.items[0].value, 45, accuracy: 1e-9)
    }

    func testCarbRatioRoundsToTenth() {
        let after = scaled(PowerProfiles_TestData.values(carbRatios: [8.3]), .carbRatios, 5)
        XCTAssertEqual(after.carbRatioSchedule.items[0].value, 8.7, accuracy: 1e-9)
    }

    func testSensitivityRoundsToWholeNumber() {
        let after = scaled(PowerProfiles_TestData.values(sensitivities: [47]), .insulinSensitivity, 15)
        XCTAssertEqual(after.insulinSensitivitySchedule.items[0].value, 54, accuracy: 1e-9) // 54.05
    }

    func testBasalRoundsToNearestSupportedRate() {
        let after = scaled(PowerProfiles_TestData.values(basalRates: [0.85]), .basalRates, 10)
        XCTAssertEqual(after.basalRateSchedule.items[0].value, 0.95, accuracy: 1e-9) // 0.935
    }

    func testBasalBelowLowestSupportedIsBlocked() {
        let before = PowerProfiles_TestData.values(basalRates: [0.05])
        let after = scaled(before, .basalRates, -50)
        XCTAssertEqual(after.basalRateSchedule.items[0].value, 0.025, accuracy: 1e-9, "not raised to 0.05")
        let rows = PowerProfiles_Review.rows(before: before, after: after, ticked: [.basalRates],
                                             supportedBasalRates: rates, maximumBasalRate: 5)
        XCTAssertEqual(rows.first?.check, .blocked)
    }

    func testEveryBasalSlotScaled() {
        let before = PowerProfiles_TestData.values(basalRates: Array(repeating: 1.0, count: 24))
        let after = scaled(before, .basalRates, 20)
        XCTAssertEqual(after.basalRateSchedule.items.count, 24)
        XCTAssertTrue(after.basalRateSchedule.items.allSatisfy { abs($0.value - 1.2) < 1e-9 })
        XCTAssertEqual(after.basalRateSchedule.items.map(\.startTime), before.basalRateSchedule.items.map(\.startTime))
        let rows = PowerProfiles_Review.rows(before: before, after: after, ticked: [.basalRates],
                                             supportedBasalRates: rates, maximumBasalRate: 5)
        XCTAssertEqual(rows.count, 24)
    }

    func testCorrectionRangeScalesBothBounds() {
        let after = scaled(PowerProfiles_TestData.values(targets: [(100, 110)]), .correctionRange, 10)
        XCTAssertEqual(after.correctionRange.items[0].value.minValue, 110, accuracy: 1e-9)
        XCTAssertEqual(after.correctionRange.items[0].value.maxValue, 121, accuracy: 1e-9)
    }

    func testUntickedScheduleUnchanged() {
        let before = PowerProfiles_TestData.values()
        let after = scaled(before, .carbRatios, 30)
        XCTAssertEqual(after.basalRateSchedule, before.basalRateSchedule)
        XCTAssertEqual(after.insulinSensitivitySchedule, before.insulinSensitivitySchedule)
        XCTAssertEqual(after.correctionRange, before.correctionRange)
        XCTAssertEqual(after.name, before.name)
    }

    func testOutsideRecommendedIsWarning() {
        let before = PowerProfiles_TestData.values(carbRatios: [25])
        let after = scaled(before, .carbRatios, 20) // 30, above recommended 28
        let rows = PowerProfiles_Review.rows(before: before, after: after, ticked: [.carbRatios],
                                             supportedBasalRates: rates, maximumBasalRate: 5)
        XCTAssertEqual(rows.first?.check, .warning)
        XCTAssertTrue(PowerProfiles_Review.canSave(rows))
    }

    func testOutsideAbsoluteIsBlocked() {
        let before = PowerProfiles_TestData.values(carbRatios: [120])
        let after = scaled(before, .carbRatios, 35) // 162, above absolute 150
        let rows = PowerProfiles_Review.rows(before: before, after: after, ticked: [.carbRatios],
                                             supportedBasalRates: rates, maximumBasalRate: 5)
        XCTAssertEqual(rows.first?.check, .blocked)
    }

    func testBasalAboveMaximumIsBlocked() {
        let before = PowerProfiles_TestData.values(basalRates: [0.85])
        let after = scaled(before, .basalRates, 50) // 1.3
        let rows = PowerProfiles_Review.rows(before: before, after: after, ticked: [.basalRates],
                                             supportedBasalRates: rates, maximumBasalRate: 1.0)
        XCTAssertEqual(rows.first?.check, .blocked)
    }

    func testCanSaveFalseWhenAnyRowBlocked() {
        let before = PowerProfiles_TestData.values(carbRatios: [10, 120])
        let after = scaled(before, .carbRatios, 35)
        let rows = PowerProfiles_Review.rows(before: before, after: after, ticked: [.carbRatios],
                                             supportedBasalRates: rates, maximumBasalRate: 5)
        XCTAssertEqual(rows.map(\.check), [.ok, .blocked])
        XCTAssertFalse(PowerProfiles_Review.canSave(rows))
    }

    func testRowsOnlyForTickedSettingsInScreenOrder() {
        let before = PowerProfiles_TestData.values()
        var adjustment = PowerProfiles_Adjustment()
        adjustment.ticked = [.correctionRange, .basalRates]
        let after = PowerProfiles_Scaler.scale(before, by: adjustment, supportedBasalRates: rates)
        let rows = PowerProfiles_Review.rows(before: before, after: after, ticked: adjustment.ticked,
                                             supportedBasalRates: rates, maximumBasalRate: 5)
        XCTAssertEqual(rows.map(\.setting), [.basalRates, .correctionRange])
        XCTAssertEqual(rows.last?.before, [100, 110])
    }

    /// Taylor, 2026-11-19: a correction range up to 125 mg/dL is not a warning,
    /// although Loop's own guardrail recommends at most 115.9.
    func testCorrectionRangeWarnsOnlyAbove125() {
        func check(_ low: Double, _ high: Double) -> PowerProfiles_Check? {
            let before = PowerProfiles_TestData.values(targets: [(100, 110)])
            let after = PowerProfiles_TestData.values(targets: [(low, high)])
            return PowerProfiles_Review.rows(before: before, after: after, ticked: [.correctionRange],
                                             supportedBasalRates: rates, maximumBasalRate: 5).first?.check
        }
        XCTAssertEqual(check(101, 116), .ok)
        XCTAssertEqual(check(110, 125), .ok)
        XCTAssertEqual(check(110, 126), .warning)
        XCTAssertEqual(check(95, 110), .warning, "Loop's lower recommended limit still applies")
        XCTAssertEqual(check(110, 185), .blocked, "Loop's absolute limit still applies")
    }

    func testMmolDisplay() {
        XCTAssertEqual(PowerProfiles_Format.glucose(100, unit: .millimolesPerLiter), "5.6")
        XCTAssertEqual(PowerProfiles_Format.glucose(100, unit: .milligramsPerDeciliter), "100")
    }
}
