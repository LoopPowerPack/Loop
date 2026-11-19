//
//  PowerProfiles_UndoStore.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerProfiles — Keeps a copy of what the last PowerProfiles save replaced,
//  on disk, so Undo still works after the app restarts.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import Foundation

enum PowerProfiles_SaveAction: String, Codable {
    case saveNew
    case saveExisting
    case saveAndLoad
    case undo
}

/// What one save replaced.
struct PowerProfiles_UndoSnapshot: Codable, Equatable {
    let action: PowerProfiles_SaveAction
    let fileName: String
    /// The file's bytes before the save; nil when the save created the file.
    let previousFileData: Data?
    /// Loop's active settings before a Save & Load; nil for the other saves.
    let previousActive: PowerProfiles_ProfileValues?
    let previousProfileName: String?
    let date: Date
}

final class PowerProfiles_UndoStore {

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PowerProfiles")
            .appendingPathComponent("undo.json")
    }

    private let url: URL

    init(url: URL = PowerProfiles_UndoStore.defaultURL) {
        self.url = url
    }

    /// Replaces any earlier snapshot: only the most recent save can be undone.
    func save(_ snapshot: PowerProfiles_UndoSnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    func load() -> PowerProfiles_UndoSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PowerProfiles_UndoSnapshot.self, from: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
