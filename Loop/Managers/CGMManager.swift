//
//  CGMManager.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import MockKit

let staticCGMManagersByIdentifier: [String: CGMManager.Type] = [
    MockCGMManager.pluginIdentifier: MockCGMManager.self,
    // DirectConnect (PowerPack) — always registered so a configured CGM restores even if the flag is later off
    DirectConnect_G7CGMManager.pluginIdentifier: DirectConnect_G7CGMManager.self
]

var availableStaticCGMManagers: [CGMManagerDescriptor] {
    // DirectConnect (PowerPack) — listed only when its feature flag is on
    let directConnect = DirectConnect_FeatureFlags.isEnabled
        ? [CGMManagerDescriptor(identifier: DirectConnect_G7CGMManager.pluginIdentifier, localizedTitle: DirectConnect_G7CGMManager.displayTitle)]
        : []
    if FeatureFlags.allowSimulators {
        return [
            CGMManagerDescriptor(identifier: MockCGMManager.pluginIdentifier, localizedTitle: MockCGMManager.localizedTitle)
        ] + directConnect
    } else {
        return directConnect
    }
}

func CGMManagerFromRawValue(_ rawValue: [String: Any]) -> CGMManager? {
    guard let managerIdentifier = rawValue["managerIdentifier"] as? String,
        let rawState = rawValue["state"] as? CGMManager.RawStateValue,
        let Manager = staticCGMManagersByIdentifier[managerIdentifier]
    else {
        return nil
    }
    
    return Manager.init(rawState: rawState)
}

extension CGMManager {

    typealias RawValue = [String: Any]
    
    var rawValue: [String: Any] {
        return [
            "managerIdentifier": pluginIdentifier,
            "state": self.rawState
        ]
    }
}
