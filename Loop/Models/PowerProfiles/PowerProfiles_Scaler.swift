//
//  PowerProfiles_Scaler.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerProfiles — Applies the chosen percentages to a profile's schedules,
//  rounds the results, and checks each new value against Loop's guardrails.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import Foundation
import HealthKit
import LoopKit

enum PowerProfiles_Scaler {

    /// The profile with each ticked schedule multiplied by (1 + percent/100) and rounded.
    /// - Parameters:
    ///   - values: Profile to change (glucose values in mg/dL).
    ///   - adjustment: Ticked settings and their percentages.
    ///   - supportedBasalRates: The pump's supported basal rates, ascending.
    /// - Returns: A copy; unticked schedules and all start times unchanged.
    static func scale(_ values: PowerProfiles_ProfileValues,
                      by adjustment: PowerProfiles_Adjustment,
                      supportedBasalRates: [Double]) -> PowerProfiles_ProfileValues {
        var result = values

        if let percent = adjustment.percent(for: .basalRates),
           let schedule = BasalRateSchedule(dailyItems: values.basalRateSchedule.items.map {
               RepeatingScheduleValue(startTime: $0.startTime,
                                      value: roundBasal($0.value * factor(percent), supportedBasalRates: supportedBasalRates))
           }, timeZone: values.basalRateSchedule.timeZone) {
            result.basalRateSchedule = schedule
        }

        if let percent = adjustment.percent(for: .carbRatios),
           let schedule = CarbRatioSchedule(unit: values.carbRatioSchedule.unit, dailyItems: values.carbRatioSchedule.items.map {
               RepeatingScheduleValue(startTime: $0.startTime, value: round($0.value * factor(percent), places: 1))
           }, timeZone: values.carbRatioSchedule.timeZone) {
            result.carbRatioSchedule = schedule
        }

        if let percent = adjustment.percent(for: .insulinSensitivity),
           let schedule = InsulinSensitivitySchedule(unit: values.insulinSensitivitySchedule.unit, dailyItems: values.insulinSensitivitySchedule.items.map {
               RepeatingScheduleValue(startTime: $0.startTime, value: round($0.value * factor(percent), places: 0))
           }, timeZone: values.insulinSensitivitySchedule.timeZone) {
            result.insulinSensitivitySchedule = schedule
        }

        if let percent = adjustment.percent(for: .correctionRange),
           let schedule = GlucoseRangeSchedule(unit: values.correctionRange.unit, dailyItems: values.correctionRange.items.map {
               RepeatingScheduleValue(startTime: $0.startTime,
                                      value: DoubleRange(minValue: round($0.value.minValue * factor(percent), places: 0),
                                                         maxValue: round($0.value.maxValue * factor(percent), places: 0)))
           }, timeZone: values.correctionRange.timeZone) {
            result.correctionRange = schedule
        }

        return result
    }

    static func factor(_ percent: Int) -> Double {
        1 + Double(percent) / 100
    }

    static func round(_ value: Double, places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (value * scale).rounded() / scale
    }

    /// The nearest supported rate. A value outside the supported range is
    /// returned unrounded so the safety check blocks it instead of the
    /// rate being silently raised or lowered to the pump's limit.
    static func roundBasal(_ value: Double, supportedBasalRates: [Double]) -> Double {
        guard let lowest = supportedBasalRates.first, let highest = supportedBasalRates.last,
              value >= lowest - tolerance, value <= highest + tolerance
        else { return value }
        return supportedBasalRates.min { abs($0 - value) < abs($1 - value) } ?? value
    }

    static let tolerance = 1e-9
}

enum PowerProfiles_Check: Equatable {
    case ok
    case warning
    case blocked
}

/// One time slot of one setting on the Before / After list.
struct PowerProfiles_Row: Identifiable, Equatable {
    let id: String
    let setting: PowerProfiles_Setting
    let startTime: TimeInterval
    /// One value, or two (minimum, maximum) for the correction range. Glucose values in mg/dL.
    let before: [Double]
    let after: [Double]
    let check: PowerProfiles_Check
}

enum PowerProfiles_Review {

    /// Before / After rows for the ticked settings, in screen order then start time.
    /// - Parameters:
    ///   - before: Profile values before the change.
    ///   - after: Values from `PowerProfiles_Scaler.scale`.
    ///   - ticked: Settings the user ticked.
    ///   - supportedBasalRates: The pump's supported basal rates.
    ///   - maximumBasalRate: Loop's maximum basal rate, if set.
    /// - Returns: One row per time slot of each ticked setting.
    static func rows(before: PowerProfiles_ProfileValues,
                     after: PowerProfiles_ProfileValues,
                     ticked: Set<PowerProfiles_Setting>,
                     supportedBasalRates: [Double],
                     maximumBasalRate: Double?) -> [PowerProfiles_Row] {
        PowerProfiles_Setting.allCases.filter(ticked.contains).flatMap { setting -> [PowerProfiles_Row] in
            switch setting {
            case .basalRates:
                return zip(before.basalRateSchedule.items, after.basalRateSchedule.items).map {
                    row(setting, $0.startTime, [$0.value], [$1.value],
                        basalCheck($1.value, supportedBasalRates: supportedBasalRates, maximumBasalRate: maximumBasalRate))
                }
            case .carbRatios:
                return zip(before.carbRatioSchedule.items, after.carbRatioSchedule.items).map {
                    row(setting, $0.startTime, [$0.value], [$1.value],
                        check(Guardrail.carbRatio, HKQuantity(unit: PowerProfiles_Units.gramsPerUnit, doubleValue: $1.value)))
                }
            case .insulinSensitivity:
                let unit = HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit())
                return zip(before.insulinSensitivitySchedule.items, after.insulinSensitivitySchedule.items).map {
                    row(setting, $0.startTime, [$0.value], [$1.value],
                        check(Guardrail.insulinSensitivity, HKQuantity(unit: unit, doubleValue: $1.value)))
                }
            case .correctionRange:
                return zip(before.correctionRange.items, after.correctionRange.items).map {
                    let low = correctionRangeCheck($1.value.minValue)
                    let high = correctionRangeCheck($1.value.maxValue)
                    return row(setting, $0.startTime, [$0.value.minValue, $0.value.maxValue],
                               [$1.value.minValue, $1.value.maxValue], worst(low, high))
                }
            }
        }
    }

    /// True when no row is blocked.
    static func canSave(_ rows: [PowerProfiles_Row]) -> Bool {
        !rows.contains { $0.check == .blocked }
    }

    private static func row(_ setting: PowerProfiles_Setting, _ startTime: TimeInterval,
                            _ before: [Double], _ after: [Double], _ check: PowerProfiles_Check) -> PowerProfiles_Row {
        PowerProfiles_Row(id: "\(setting.rawValue)-\(Int(startTime))", setting: setting, startTime: startTime,
                          before: before, after: after, check: check)
    }

    private static func check(_ guardrail: Guardrail<HKQuantity>, _ value: HKQuantity) -> PowerProfiles_Check {
        guard guardrail.absoluteBounds.contains(value) else { return .blocked }
        return guardrail.classification(for: value) == .withinRecommendedRange ? .ok : .warning
    }

    /// Correction range values outside 95–125 mg/dL are shown orange. Taylor, 2026-11-19:
    /// Loop's own recommended range (99.1–115.9 mg/dL) marked ordinary targets such as 116.
    static let correctionRangeWarningBelow: Double = 95
    static let correctionRangeWarningAbove: Double = 125

    /// Red outside Loop's absolute correction range limits; orange below
    /// `correctionRangeWarningBelow` or above `correctionRangeWarningAbove`.
    private static func correctionRangeCheck(_ mgdl: Double) -> PowerProfiles_Check {
        let guardrail = Guardrail.correctionRange
        let unit = HKUnit.milligramsPerDeciliter
        guard guardrail.absoluteBounds.contains(HKQuantity(unit: unit, doubleValue: mgdl)) else { return .blocked }
        if mgdl < correctionRangeWarningBelow || mgdl > correctionRangeWarningAbove {
            return .warning
        }
        return .ok
    }

    private static func basalCheck(_ value: Double, supportedBasalRates: [Double], maximumBasalRate: Double?) -> PowerProfiles_Check {
        let supported = supportedBasalRates.contains { abs($0 - value) < PowerProfiles_Scaler.tolerance }
        if value <= 0 || !supported { return .blocked }
        if let maximumBasalRate, value > maximumBasalRate + PowerProfiles_Scaler.tolerance { return .blocked }
        return .ok
    }

    private static func worst(_ a: PowerProfiles_Check, _ b: PowerProfiles_Check) -> PowerProfiles_Check {
        if a == .blocked || b == .blocked { return .blocked }
        if a == .warning || b == .warning { return .warning }
        return .ok
    }
}

enum PowerProfiles_Units {
    /// g/U. LoopKit's `HKUnit.gramsPerUnit` is internal to LoopKit.
    static let gramsPerUnit = HKUnit.gram().unitDivided(by: .internationalUnit())
}

enum PowerProfiles_Format {
    /// A glucose value for display: whole mg/dL, or mmol/L to 0.1.
    /// - Parameters:
    ///   - mgdl: Value in mg/dL.
    ///   - unit: The user's glucose unit.
    static func glucose(_ mgdl: Double, unit: HKUnit) -> String {
        if unit == .millimolesPerLiter {
            let mmol = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdl).doubleValue(for: .millimolesPerLiter)
            return String(format: "%.1f", mmol)
        }
        return String(format: "%.0f", mgdl)
    }
}
