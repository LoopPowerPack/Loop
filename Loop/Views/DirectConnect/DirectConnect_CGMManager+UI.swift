//
//  DirectConnect_CGMManager+UI.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//  DirectConnect — CGMManagerUI conformance: setup, settings and status indicators.
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Adapted from LoopKit G7SensorKitUI G7CGMManager+UI (MIT, © 2022 LoopKit Authors).
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.

import Foundation
import LoopKit
import LoopKitUI
import UIKit

struct DirectConnect_StatusHighlight: DeviceStatusHighlight, Equatable {
    let localizedMessage: String
    let imageName: String
    let state: DeviceStatusHighlightState
}

struct DirectConnect_StatusBadge: DeviceStatusBadge {
    var image: UIImage?
    var state: DeviceStatusBadgeState
}

struct DirectConnect_LifecycleProgress: DeviceLifecycleProgress {
    var percentComplete: Double
    var progressState: DeviceLifecycleProgressState
}

extension DirectConnect_G7CGMManager: CGMManagerUI {
    static var onboardingImage: UIImage? { nil }

    static func setupViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, prefersToSkipUserInteraction: Bool) -> SetupUIResult<CGMManagerViewController, CGMManagerUI> {
        .userInteractionRequired(DirectConnect_UICoordinator(colorPalette: colorPalette, displayGlucosePreference: displayGlucosePreference))
    }

    func settingsViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> CGMManagerViewController {
        DirectConnect_UICoordinator(cgmManager: self, colorPalette: colorPalette, displayGlucosePreference: displayGlucosePreference)
    }

    var smallImage: UIImage? {
        DirectConnect_Branding.tintedIcon
    }

    var cgmStatusHighlight: DeviceStatusHighlight? {
        if state.pairingFailure != nil {
            return DirectConnect_StatusHighlight(localizedMessage: NSLocalizedString("Pairing\nProblem", comment: "DirectConnect highlight pairing problem"), imageName: "exclamationmark.circle.fill", state: .critical)
        }
        switch lifecycleState {
        case .notPaired, .searching:
            return DirectConnect_StatusHighlight(localizedMessage: NSLocalizedString("Searching for\nSensor", comment: "DirectConnect highlight searching"), imageName: "dot.radiowaves.left.and.right", state: .normalCGM)
        case .expired:
            return DirectConnect_StatusHighlight(localizedMessage: NSLocalizedString("Sensor\nExpired", comment: "DirectConnect highlight expired"), imageName: "clock", state: .normalCGM)
        case .failed:
            return DirectConnect_StatusHighlight(localizedMessage: NSLocalizedString("Sensor\nFailed", comment: "DirectConnect highlight failed"), imageName: "exclamationmark.circle.fill", state: .critical)
        default:
            break
        }
        if let last = state.latestReadingTimestamp, last.timeIntervalSinceNow < -.minutes(15) {
            return DirectConnect_StatusHighlight(localizedMessage: NSLocalizedString("Signal\nLoss", comment: "DirectConnect highlight signal loss"), imageName: "exclamationmark.circle.fill", state: .warning)
        }
        if state.latestReading?.algorithmState.hasTemporaryError == true {
            return DirectConnect_StatusHighlight(localizedMessage: NSLocalizedString("Sensor\nIssue", comment: "DirectConnect highlight sensor issue"), imageName: "exclamationmark.circle.fill", state: .warning)
        }
        if lifecycleState == .warmup {
            return DirectConnect_StatusHighlight(localizedMessage: NSLocalizedString("Sensor\nWarmup", comment: "DirectConnect highlight warmup"), imageName: "clock", state: .normalCGM)
        }
        return nil
    }

    var cgmStatusBadge: DeviceStatusBadge? {
        lifecycleState == .gracePeriod ? DirectConnect_StatusBadge(image: UIImage(systemName: "clock"), state: .critical) : nil
    }

    var cgmLifecycleProgress: DeviceLifecycleProgress? {
        switch lifecycleState {
        case .ok:
            guard let expiration = sensorExpiresAt else { return nil }
            let remaining = max(0, expiration.timeIntervalSinceNow)
            guard remaining < .hours(48) else { return nil }
            return DirectConnect_LifecycleProgress(percentComplete: 1 - remaining / lifetime, progressState: remaining < .hours(24) ? .warning : .normalCGM)
        case .gracePeriod:
            guard let end = sensorEndsAt else { return nil }
            let remaining = max(0, end.timeIntervalSinceNow)
            return DirectConnect_LifecycleProgress(percentComplete: 1 - remaining / DirectConnect_SensorLifetime.gracePeriod, progressState: .critical)
        case .expired:
            return DirectConnect_LifecycleProgress(percentComplete: 1, progressState: .critical)
        default:
            return nil
        }
    }
}
