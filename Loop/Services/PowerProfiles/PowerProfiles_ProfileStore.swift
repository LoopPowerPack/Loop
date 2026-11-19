//
//  PowerProfiles_ProfileStore.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//
//  PowerProfiles — Reads and writes saved profiles in the folder and file
//  format the Profiles feature uses, so both see the same profile library.
//
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.
//

import Foundation

struct PowerProfiles_StoredProfile: Equatable {
    let fileName: String
    let values: PowerProfiles_ProfileValues
}

enum PowerProfiles_StoreError: LocalizedError, Equatable {
    case nameExists(String)
    case emptyName
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .nameExists(let name):
            return String(format: NSLocalizedString("A profile named \"%@\" already exists. Choose another name, or load that profile and use Save to it.", comment: "PowerProfiles error when a new profile name is taken"), name)
        case .emptyName:
            return NSLocalizedString("Enter a name for the profile.", comment: "PowerProfiles error when the profile name is empty")
        case .notFound:
            return NSLocalizedString("The profile file was not found. It may have been deleted on the Profiles page.", comment: "PowerProfiles error when a profile file is missing")
        }
    }
}

final class PowerProfiles_ProfileStore {

    /// `Documents/LoopProfile`, the folder Profiles uses.
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("LoopProfile")
    }

    private let directory: URL

    init(directory: URL = PowerProfiles_ProfileStore.defaultDirectory) {
        self.directory = directory
    }

    /// The name Profiles would store: "." and "<" become "_", at most 32 characters.
    static func sanitize(_ name: String) -> String {
        let replaced = name.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "<", with: "_")
        return String(replaced.prefix(32))
    }

    /// Every readable profile, sorted as the Profiles page sorts them. Unreadable files are skipped.
    func loadAll() -> [PowerProfiles_StoredProfile] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> PowerProfiles_StoredProfile? in
                guard let data = try? Data(contentsOf: url),
                      let values = try? JSONDecoder().decode(PowerProfiles_ProfileValues.self, from: data)
                else { return nil }
                return PowerProfiles_StoredProfile(fileName: url.lastPathComponent, values: values)
            }
            .sorted { ($0.values.sortOrder ?? 0) < ($1.values.sortOrder ?? 0) }
    }

    /// The file's bytes, or nil when it does not exist.
    func data(fileName: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(fileName))
    }

    /// Writes a new profile file at the top of the list (sortOrder −1, as Profiles does).
    /// - Parameters:
    ///   - values: Profile values; the name is sanitized.
    ///   - now: Time used for the file name.
    /// - Returns: The new file's name.
    /// - Throws: `nameExists` when a profile already has the sanitized name, `emptyName`, or a file error.
    func createNew(_ values: PowerProfiles_ProfileValues, now: Date = Date()) throws -> String {
        let name = Self.sanitize(values.name.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !name.isEmpty else { throw PowerProfiles_StoreError.emptyName }
        guard !loadAll().contains(where: { Self.sanitize($0.values.name) == name }) else {
            throw PowerProfiles_StoreError.nameExists(name)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        var date = now
        var fileName = formatter.string(from: date) + ".json"
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(fileName).path) {
            date = date.addingTimeInterval(1)
            fileName = formatter.string(from: date) + ".json"
        }

        var profile = values
        profile.name = name
        profile.sortOrder = -1
        try JSONEncoder().encode(profile).write(to: directory.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    /// Replaces an existing profile file's contents, keeping its file name.
    func overwrite(_ values: PowerProfiles_ProfileValues, fileName: String) throws {
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PowerProfiles_StoreError.notFound(fileName)
        }
        try JSONEncoder().encode(values).write(to: url, options: .atomic)
    }

    /// Puts a file back as it was: writes `data`, or deletes the file when `data` is nil.
    func restore(fileName: String, data: Data?) throws {
        let url = directory.appendingPathComponent(fileName)
        if let data {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
