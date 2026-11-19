//
//  PowerProfiles_Models.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerProfiles — The feature switch, the slider rules, the user's chosen
//  percentages, and the profile values in the same JSON form Profiles saves.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import Foundation
import HealthKit
import LoopKit

enum PowerProfiles_FeatureFlags {
    enum Keys {
        static let isEnabled = "PowerProfiles.isEnabled"
    }
}

/// The therapy settings PowerProfiles can change, in screen order.
enum PowerProfiles_Setting: String, CaseIterable, Codable, Identifiable {
    case basalRates
    case carbRatios
    case insulinSensitivity
    case correctionRange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basalRates: return NSLocalizedString("Basal Rates", comment: "PowerProfiles setting name")
        case .carbRatios: return NSLocalizedString("Carb Ratios", comment: "PowerProfiles setting name")
        case .insulinSensitivity: return NSLocalizedString("Insulin Sensitivities", comment: "PowerProfiles setting name")
        case .correctionRange: return NSLocalizedString("Correction Range", comment: "PowerProfiles setting name")
        }
    }
}

enum PowerProfiles_Slider {
    static let range: ClosedRange<Int> = -50...50
    static let step = 5

    /// The nearest step inside the range. Halves round away from zero.
    /// - Parameter value: Raw slider position in percent.
    /// - Returns: A multiple of `step` within `range`.
    static func snap(_ value: Double) -> Int {
        let snapped = Int((value / Double(step)).rounded()) * step
        return min(max(snapped, range.lowerBound), range.upperBound)
    }
}

/// Which settings change and by how much.
struct PowerProfiles_Adjustment: Equatable, Codable {
    var isLocked = false
    var lockedPercent = 0
    var percents: [PowerProfiles_Setting: Int] = [:]
    var ticked: Set<PowerProfiles_Setting> = []

    /// The percentage applied to `setting`, or nil when it is not ticked.
    /// - Parameter setting: The therapy setting.
    /// - Returns: `lockedPercent` when locked, else the setting's own percent (0 when unset).
    func percent(for setting: PowerProfiles_Setting) -> Int? {
        guard ticked.contains(setting) else { return nil }
        return isLocked ? lockedPercent : (percents[setting] ?? 0)
    }
}

/// One profile's values. Property names match LoopKitUI's `Profile`, so the
/// JSON is the same file format Profiles reads and writes. Glucose values are mg/dL.
struct PowerProfiles_ProfileValues: Codable, Equatable {
    var name: String
    var correctionRange: GlucoseRangeSchedule
    var carbRatioSchedule: CarbRatioSchedule
    var basalRateSchedule: BasalRateSchedule
    var insulinSensitivitySchedule: InsulinSensitivitySchedule
    var sortOrder: Int?

    /// Loop's active settings as profile values, converted to mg/dL as Profiles does.
    /// - Parameters:
    ///   - name: Name to give the values.
    ///   - settings: Active therapy settings.
    /// - Returns: nil when any of the four schedules is missing.
    static func current(name: String, from settings: TherapySettings) -> PowerProfiles_ProfileValues? {
        guard let range = settings.glucoseTargetRangeSchedule?.schedule(for: .milligramsPerDeciliter),
              let carbRatios = settings.carbRatioSchedule,
              let basalRates = settings.basalRateSchedule,
              let sensitivities = settings.insulinSensitivitySchedule?.schedule(for: .milligramsPerDeciliter)
        else { return nil }
        return PowerProfiles_ProfileValues(name: name,
                                           correctionRange: range,
                                           carbRatioSchedule: carbRatios,
                                           basalRateSchedule: basalRates,
                                           insulinSensitivitySchedule: sensitivities,
                                           sortOrder: nil)
    }
}
