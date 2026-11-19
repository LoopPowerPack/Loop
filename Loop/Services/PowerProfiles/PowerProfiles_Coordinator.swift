//
//  PowerProfiles_Coordinator.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerProfiles — Runs the three saves and Undo: writes profile files,
//  loads a profile through the Profiles feature, and records what each save
//  replaced so Undo can put it back.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import Foundation
import LoopKit
import LoopKitUI

/// Loop's active therapy settings, as seen by PowerProfiles.
protocol PowerProfiles_ProfileLoading: AnyObject {
    var activeValues: PowerProfiles_ProfileValues? { get }
    var activeProfileName: String? { get set }
    /// Makes `values` Loop's active settings (writes the basal schedule to the pump first).
    func activate(_ values: PowerProfiles_ProfileValues, completion: @escaping (Result<Void, Error>) -> Void)
}

/// Loads profiles through the Profiles feature's public `ProfileViewModel` API,
/// so loading runs the same checks and pump write as the Profiles page.
final class PowerProfiles_ProfileViewModelLoader: PowerProfiles_ProfileLoading {

    private let viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }

    var activeValues: PowerProfiles_ProfileValues? {
        PowerProfiles_ProfileValues.current(name: viewModel.currentProfileName ?? "", from: viewModel.therapySettings)
    }

    var activeProfileName: String? {
        get { viewModel.currentProfileName }
        set { viewModel.currentProfileName = newValue }
    }

    func activate(_ values: PowerProfiles_ProfileValues, completion: @escaping (Result<Void, Error>) -> Void) {
        let profile: Profile
        do {
            // PowerProfiles_ProfileValues has the same JSON form as Profile, whose initializer is internal to LoopKitUI.
            profile = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(values))
        } catch {
            completion(.failure(error))
            return
        }
        if case .failure(let error) = viewModel.validateProfile(profile) {
            completion(.failure(error))
            return
        }
        viewModel.loadProfile(profile: profile) { [viewModel] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    viewModel.loadProfiles()
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}

final class PowerProfiles_Coordinator {

    /// Posted after every save and Undo. userInfo: `action` (String), `profileName` (String), `percents` ([String: Int]).
    static let savedNotification = Notification.Name("com.loopkit.Loop.powerProfilesSaved")

    private let store: PowerProfiles_ProfileStore
    private let undoStore: PowerProfiles_UndoStore
    private let loader: PowerProfiles_ProfileLoading
    private let notificationCenter: NotificationCenter

    init(store: PowerProfiles_ProfileStore,
         undoStore: PowerProfiles_UndoStore,
         loader: PowerProfiles_ProfileLoading,
         notificationCenter: NotificationCenter = .default) {
        self.store = store
        self.undoStore = undoStore
        self.loader = loader
        self.notificationCenter = notificationCenter
    }

    var canUndo: Bool {
        undoStore.load() != nil
    }

    /// The profile name the last save wrote, for the Undo button label.
    var undoProfileName: String? {
        guard let snapshot = undoStore.load() else { return nil }
        return store.loadAll().first { $0.fileName == snapshot.fileName }?.values.name
    }

    /// Saves `values` as a new profile. Does not load it.
    /// - Returns: The new file's name.
    @discardableResult
    func saveNew(_ values: PowerProfiles_ProfileValues, adjustment: PowerProfiles_Adjustment) throws -> String {
        let fileName = try store.createNew(values)
        try? undoStore.save(snapshot(.saveNew, fileName: fileName, previousFileData: nil))
        post(.saveNew, name: PowerProfiles_ProfileStore.sanitize(values.name), adjustment: adjustment)
        return fileName
    }

    /// Overwrites the profile in `fileName`. Does not load it.
    func saveExisting(_ values: PowerProfiles_ProfileValues, fileName: String, adjustment: PowerProfiles_Adjustment) throws {
        guard let previous = store.data(fileName: fileName) else {
            throw PowerProfiles_StoreError.notFound(fileName)
        }
        try undoStore.save(snapshot(.saveExisting, fileName: fileName, previousFileData: previous))
        try store.overwrite(values, fileName: fileName)
        post(.saveExisting, name: values.name, adjustment: adjustment)
    }

    /// Saves `values` (new profile when `fileName` is nil) and loads it.
    /// When loading fails, the file is put back as it was and nothing can be undone.
    func saveAndLoad(_ values: PowerProfiles_ProfileValues,
                     fileName: String?,
                     adjustment: PowerProfiles_Adjustment,
                     completion: @escaping (Result<Void, Error>) -> Void) {
        let previousActive = loader.activeValues
        let previousName = loader.activeProfileName
        let writtenFile: String
        let previousData: Data?
        var saved = values
        do {
            if let fileName {
                guard let data = store.data(fileName: fileName) else {
                    throw PowerProfiles_StoreError.notFound(fileName)
                }
                previousData = data
                try store.overwrite(values, fileName: fileName)
                writtenFile = fileName
            } else {
                previousData = nil
                writtenFile = try store.createNew(values)
                saved.name = PowerProfiles_ProfileStore.sanitize(values.name.trimmingCharacters(in: .whitespacesAndNewlines))
                saved.sortOrder = -1
            }
        } catch {
            completion(.failure(error))
            return
        }

        loader.activate(saved) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                try? self.undoStore.save(PowerProfiles_UndoSnapshot(action: .saveAndLoad,
                                                                    fileName: writtenFile,
                                                                    previousFileData: previousData,
                                                                    previousActive: previousActive,
                                                                    previousProfileName: previousName,
                                                                    date: Date()))
                self.post(.saveAndLoad, name: saved.name, adjustment: adjustment)
                completion(.success(()))
            case .failure(let error):
                try? self.store.restore(fileName: writtenFile, data: previousData)
                completion(.failure(error))
            }
        }
    }

    /// Puts back what the last save replaced. Does nothing when there is nothing to undo.
    func undo(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let snapshot = undoStore.load() else {
            completion(.success(()))
            return
        }
        do {
            try store.restore(fileName: snapshot.fileName, data: snapshot.previousFileData)
        } catch {
            completion(.failure(error))
            return
        }

        let finish = { [weak self] in
            guard let self else { return }
            self.undoStore.clear()
            self.post(.undo, name: snapshot.previousProfileName ?? "", adjustment: PowerProfiles_Adjustment())
            completion(.success(()))
        }

        guard snapshot.action == .saveAndLoad, let previousActive = snapshot.previousActive else {
            finish()
            return
        }
        loader.activate(previousActive) { [weak self] result in
            switch result {
            case .success:
                self?.loader.activeProfileName = snapshot.previousProfileName
                finish()
            case .failure(let error):
                // The snapshot stays, so Undo can be tried again (restoring the file twice is harmless).
                completion(.failure(error))
            }
        }
    }

    private func snapshot(_ action: PowerProfiles_SaveAction, fileName: String, previousFileData: Data?) -> PowerProfiles_UndoSnapshot {
        PowerProfiles_UndoSnapshot(action: action, fileName: fileName, previousFileData: previousFileData,
                                   previousActive: nil, previousProfileName: nil, date: Date())
    }

    private func post(_ action: PowerProfiles_SaveAction, name: String, adjustment: PowerProfiles_Adjustment) {
        var percents: [String: Int] = [:]
        for setting in PowerProfiles_Setting.allCases {
            if let percent = adjustment.percent(for: setting) {
                percents[setting.rawValue] = percent
            }
        }
        notificationCenter.post(name: Self.savedNotification, object: nil,
                                userInfo: ["action": action.rawValue, "profileName": name, "percents": percents])
    }
}
