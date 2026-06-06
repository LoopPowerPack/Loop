//
//  PowerPack_UpdateChecker.swift
//  Loop
//
//  PowerPack — Daily check for a newer PowerPack release. Surfaces a soft,
//  dismiss-once-per-version notice on PowerPack screens pointing users to the
//  GitHub install page. Independent of DataLayer and any consent state.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

/// Compares the running PowerPack version against the latest published release
/// (a small `version.json` on the installer branch) at most once per day, and
/// exposes a one-time-per-version update notice for PowerPack surfaces to show.
@MainActor
final class PowerPack_UpdateChecker: ObservableObject {

    static let shared = PowerPack_UpdateChecker()

    struct UpdateInfo: Equatable {
        let latest: String
        let notes: String?
        let url: URL
    }

    /// Non-nil when a newer, not-yet-dismissed version is available.
    @Published private(set) var availableUpdate: UpdateInfo?

    /// Where the latest published version lives. Editable without an app build —
    /// bump `version.json` on the installer branch and clients pick it up next day.
    private let manifestURL = URL(string:
        "https://raw.githubusercontent.com/LoopPowerPack/LoopWorkspace/feat/installer/version.json")!
    private let fallbackInstallURL = URL(string: "https://github.com/LoopPowerPack/LoopWorkspace")!

    private static let checkInterval: TimeInterval = 86_400 // 24h

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let lastCheck = "PowerPack_lastUpdateCheck"
        static let dismissedVersion = "PowerPack_dismissedUpdateVersion"
        static let cachedLatest = "PowerPack_cachedLatestVersion"
        static let cachedNotes = "PowerPack_cachedLatestNotes"
        static let cachedURL = "PowerPack_cachedLatestURL"
    }

    private init() {}

    /// Re-evaluate the update notice. Fetches the manifest over the network at
    /// most once per 24h; within that window it recomputes from the cached
    /// manifest so the notice still appears on PowerPack screens. Safe to call
    /// from any view's `.task` — self-throttling and failure-silent.
    func refresh() async {
        if isFetchDue {
            await fetchManifest()
        }
        recomputeNotice()
    }

    /// Dismiss the current notice. It won't reappear until a newer version ships.
    func dismissCurrent() {
        if let latest = availableUpdate?.latest {
            defaults.set(latest, forKey: Keys.dismissedVersion)
        }
        availableUpdate = nil
    }

    // MARK: - Internals

    private var isFetchDue: Bool {
        guard let last = defaults.object(forKey: Keys.lastCheck) as? Date else { return true }
        return Date().timeIntervalSince(last) >= Self.checkInterval
    }

    private func fetchManifest() async {
        do {
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            defaults.set(Date(), forKey: Keys.lastCheck)
            defaults.set(manifest.latest, forKey: Keys.cachedLatest)
            defaults.set(manifest.notes, forKey: Keys.cachedNotes)
            defaults.set(manifest.url, forKey: Keys.cachedURL)
        } catch {
            // Silent by design: a failed update check must never disrupt the app.
        }
    }

    private func recomputeNotice() {
        guard let latest = defaults.string(forKey: Keys.cachedLatest), !latest.isEmpty else {
            availableUpdate = nil
            return
        }
        let dismissed = defaults.string(forKey: Keys.dismissedVersion)
        guard Self.isNewer(latest, than: PowerPack_BuildInfo.version), latest != dismissed else {
            availableUpdate = nil
            return
        }
        let url = defaults.string(forKey: Keys.cachedURL).flatMap(URL.init(string:)) ?? fallbackInstallURL
        availableUpdate = UpdateInfo(latest: latest,
                                     notes: defaults.string(forKey: Keys.cachedNotes),
                                     url: url)
    }

    private struct Manifest: Decodable {
        let latest: String
        let notes: String?
        let url: String?
    }

    /// Numeric semver comparison. Ignores any pre-release suffix ("0.2.0-dev" → 0.2.0).
    static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            (s.split(separator: "-").first.map(String.init) ?? s)
                .split(separator: ".").map { Int($0) ?? 0 }
        }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let xi = i < x.count ? x[i] : 0
            let yi = i < y.count ? y[i] : 0
            if xi != yi { return xi > yi }
        }
        return false
    }
}

// MARK: - Soft update notice modifier

/// Attach to a PowerPack screen's root view. Runs the daily-throttled check on
/// appear and shows a soft, dismiss-once-per-version alert linking to the
/// install page.
struct PowerPackUpdateNotice: ViewModifier {
    @ObservedObject private var checker = PowerPack_UpdateChecker.shared
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .task { await checker.refresh() }
            .alert("PowerPack update available",
                   isPresented: Binding(
                       get: { checker.availableUpdate != nil },
                       set: { if !$0 { checker.dismissCurrent() } }
                   ),
                   presenting: checker.availableUpdate) { info in
                Button("How to update") {
                    openURL(info.url)
                    checker.dismissCurrent()
                }
                Button("Later", role: .cancel) { checker.dismissCurrent() }
            } message: { info in
                Text(message(for: info))
            }
    }

    private func message(for info: PowerPack_UpdateChecker.UpdateInfo) -> String {
        var msg = "PowerPack \(info.latest) is available (you're on \(PowerPack_BuildInfo.version)). Reinstall at your convenience to get the latest fixes."
        if let notes = info.notes, !notes.isEmpty {
            msg += "\n\nWhat's new: \(notes)"
        }
        return msg
    }
}

extension View {
    /// Show the once-per-version PowerPack update notice on this screen.
    func powerPackUpdateNotice() -> some View {
        modifier(PowerPackUpdateNotice())
    }
}
