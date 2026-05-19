//
//  PowerPack_BuildInfo.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerPack-specific version + build metadata. Surfaced in the small
//  version footer at the bottom of LoopInsights dashboard and FoodFinder
//  Settings so users can report exactly which release of PowerPack
//  they're running.
//
//  Auto-stamped values: `commitShortSHA`, `buildDate`.
//  Stamped by Scripts/install_features.sh Phase 4c at install time,
//  pulling the actual Loop submodule short SHA + install date. The
//  defaults committed in this file represent a "developer build" — that's
//  what Option A users (direct clone + Xcode) see, and it correctly
//  distinguishes their build from an installer-stamped one.
//
//  Manually-maintained value: `version`. Bumped in
//  install_features.sh's FEATURE_VERSION constant at meaningful release
//  points (new features shipping, major bug fixes, etc.).
//
//  Version → commit mapping is preserved on the LoopPowerPack/Loop repo
//  via the commit log + tags. When a user reports "I'm on PowerPack v0.1.0
//  (8bd0a85)", you can `git -C Loop checkout 8bd0a85` to reproduce their
//  exact state.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import Foundation

enum PowerPack_BuildInfo {
    /// Semver string. Manually bumped in install_features.sh at release
    /// points. The committed default here is what Option A clone-and-build
    /// users see; the installer overwrites this with FEATURE_VERSION from
    /// install_features.sh at Phase 4c.
    static let version = "0.1.0"

    /// Loop submodule short SHA at install time. `"dev"` for Option A
    /// developer builds (direct clone + Xcode); a real 7-char short SHA
    /// for Option B users (installer overlay onto stock Loop).
    static let commitShortSHA = "dev"

    /// Install date in YYYY-MM-DD UTC. Empty for developer builds.
    static let buildDate = ""

    /// User-facing display string for the footer card. Two formats:
    ///   "PowerPack v0.1.0 (8bd0a85)" — installer build
    ///   "PowerPack v0.1.0-dev"        — developer build (Option A)
    static var displayString: String {
        if commitShortSHA == "dev" || commitShortSHA.isEmpty {
            return "PowerPack v\(version)-dev"
        }
        return "PowerPack v\(version) (\(commitShortSHA))"
    }
}
