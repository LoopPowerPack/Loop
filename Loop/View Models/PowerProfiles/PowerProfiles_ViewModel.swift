//
//  PowerProfiles_ViewModel.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerProfiles — State for the PowerProfiles screen: the chosen profile,
//  the sliders and ticks, the Before / After rows, and the save buttons.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import Foundation
import LoopKit
import LoopKitUI

final class PowerProfiles_ViewModel: ObservableObject {

    /// The profile the percentages are applied to.
    enum Base: Hashable {
        case current
        case saved(fileName: String)
    }

    @Published var adjustment = PowerProfiles_Adjustment()
    @Published var base: Base = .current
    @Published var newName = ""
    @Published private(set) var savedProfiles: [PowerProfiles_StoredProfile] = []
    @Published private(set) var canUndo = false
    @Published private(set) var isWorking = false
    @Published var message: String?

    let profileViewModel: ProfileViewModel
    private let store: PowerProfiles_ProfileStore
    private let coordinator: PowerProfiles_Coordinator

    init(profileViewModel: ProfileViewModel,
         store: PowerProfiles_ProfileStore = PowerProfiles_ProfileStore(),
         undoStore: PowerProfiles_UndoStore = PowerProfiles_UndoStore()) {
        self.profileViewModel = profileViewModel
        self.store = store
        self.coordinator = PowerProfiles_Coordinator(store: store, undoStore: undoStore,
                                                     loader: PowerProfiles_ProfileViewModelLoader(viewModel: profileViewModel))
        reload()
    }

    var supportedBasalRates: [Double] {
        profileViewModel.pumpSupportedIncrements()?.basalRates ?? []
    }

    var maximumBasalRate: Double? {
        profileViewModel.therapySettings.maximumBasalRatePerHour
    }

    /// The saved profile chosen as the base, or nil for Loop's current settings.
    var baseProfile: PowerProfiles_StoredProfile? {
        guard case .saved(let fileName) = base else { return nil }
        return savedProfiles.first { $0.fileName == fileName }
    }

    var before: PowerProfiles_ProfileValues? {
        if let baseProfile { return baseProfile.values }
        return PowerProfiles_ProfileValues.current(name: "", from: profileViewModel.therapySettings)
    }

    var after: PowerProfiles_ProfileValues? {
        before.map { PowerProfiles_Scaler.scale($0, by: adjustment, supportedBasalRates: supportedBasalRates) }
    }

    var rows: [PowerProfiles_Row] {
        guard let before, let after else { return [] }
        return PowerProfiles_Review.rows(before: before, after: after, ticked: adjustment.ticked,
                                         supportedBasalRates: supportedBasalRates, maximumBasalRate: maximumBasalRate)
    }

    /// True when something is ticked, nothing is blocked, and the pump's rates are known.
    var canSave: Bool {
        !isWorking && !adjustment.ticked.isEmpty && !supportedBasalRates.isEmpty && PowerProfiles_Review.canSave(rows)
    }

    var hasNewName: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Sliders

    func percent(for setting: PowerProfiles_Setting) -> Int {
        adjustment.isLocked ? adjustment.lockedPercent : (adjustment.percents[setting] ?? 0)
    }

    func setPercent(_ value: Double, for setting: PowerProfiles_Setting) {
        adjustment.percents[setting] = PowerProfiles_Slider.snap(value)
    }

    func setLockedPercent(_ value: Double) {
        adjustment.lockedPercent = PowerProfiles_Slider.snap(value)
    }

    func toggleTick(_ setting: PowerProfiles_Setting) {
        if adjustment.ticked.contains(setting) {
            adjustment.ticked.remove(setting)
        } else {
            adjustment.ticked.insert(setting)
        }
    }

    /// Locking copies the first ticked setting's percent to the shared slider.
    func toggleLock() {
        if !adjustment.isLocked {
            let first = PowerProfiles_Setting.allCases.first { adjustment.ticked.contains($0) }
            adjustment.lockedPercent = first.flatMap { adjustment.percents[$0] } ?? adjustment.lockedPercent
        }
        adjustment.isLocked.toggle()
    }

    // MARK: Saving

    func reload() {
        savedProfiles = store.loadAll()
        canUndo = coordinator.canUndo
        if case .saved = base, baseProfile == nil {
            base = .current
        }
    }

    func saveNew() {
        guard let after else { return }
        perform {
            var values = after
            values.name = self.newName
            let fileName = try self.coordinator.saveNew(values, adjustment: self.adjustment)
            self.finishSave(selecting: fileName,
                            message: String(format: NSLocalizedString("Saved new profile \"%@\". It is not loaded.", comment: "PowerProfiles message after Save as New"), PowerProfiles_ProfileStore.sanitize(values.name)))
        }
    }

    func saveExisting() {
        guard let after, let baseProfile else { return }
        perform {
            var values = after
            values.name = baseProfile.values.name
            values.sortOrder = baseProfile.values.sortOrder
            try self.coordinator.saveExisting(values, fileName: baseProfile.fileName, adjustment: self.adjustment)
            self.finishSave(selecting: baseProfile.fileName,
                            message: String(format: NSLocalizedString("Saved to \"%@\".", comment: "PowerProfiles message after saving to the loaded profile"), values.name)
                                + (self.profileViewModel.currentProfileName == values.name
                                   ? " " + NSLocalizedString("This is the active profile. Use Save & Load to make Loop use the new values.", comment: "PowerProfiles note when the saved profile is active")
                                   : ""))
        }
    }

    /// Saves to the chosen saved profile, or as a new profile when the base is the current settings, then loads it.
    func saveAndLoad() {
        guard var values = after else { return }
        let fileName = baseProfile?.fileName
        if let baseProfile {
            values.name = baseProfile.values.name
            values.sortOrder = baseProfile.values.sortOrder
        } else {
            values.name = newName
        }
        isWorking = true
        coordinator.saveAndLoad(values, fileName: fileName, adjustment: adjustment) { [weak self] result in
            guard let self else { return }
            self.isWorking = false
            switch result {
            case .success:
                let saved = self.store.loadAll().first { PowerProfiles_ProfileStore.sanitize($0.values.name) == PowerProfiles_ProfileStore.sanitize(values.name) }
                self.finishSave(selecting: saved?.fileName,
                                message: String(format: NSLocalizedString("Saved and loaded \"%@\". Loop now uses it.", comment: "PowerProfiles message after Save & Load"), PowerProfiles_ProfileStore.sanitize(values.name)))
            case .failure(let error):
                self.message = error.localizedDescription
            }
        }
    }

    func undo() {
        isWorking = true
        coordinator.undo { [weak self] result in
            guard let self else { return }
            self.isWorking = false
            switch result {
            case .success:
                self.reload()
                self.message = NSLocalizedString("The last PowerProfiles save was undone.", comment: "PowerProfiles message after Undo")
            case .failure(let error):
                self.message = error.localizedDescription
            }
        }
    }

    private func perform(_ body: () throws -> Void) {
        do {
            try body()
        } catch {
            message = error.localizedDescription
        }
    }

    /// After a save, the saved profile becomes the base and the sliders reset,
    /// so Before shows the saved values and a second tap cannot apply the percent twice.
    private func finishSave(selecting fileName: String?, message: String) {
        reload()
        if let fileName, savedProfiles.contains(where: { $0.fileName == fileName }) {
            base = .saved(fileName: fileName)
        }
        adjustment.percents = [:]
        adjustment.lockedPercent = 0
        newName = ""
        self.message = message
    }
}
