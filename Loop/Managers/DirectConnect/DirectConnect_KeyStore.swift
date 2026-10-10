//
//  DirectConnect_KeyStore.swift
//  Loop (AID) PowerPack — based on LoopKit/Loop.
//  DirectConnect — Storage for the confirmed per-sensor pairing key.
//  Idea by Taylor Patterson. Coded by Claude Code.
//  Copyright © 2026 LoopKit Authors and Taylor Patterson.

import Foundation
import Security

protocol DirectConnect_KeyStoring: AnyObject {
    func key(sensor: String, slot: UInt8) -> Data?
    func save(_ key: Data, sensor: String, slot: UInt8)
    func delete(sensor: String)
}

/// Keychain-backed store. xDrip4iOS keeps this key in UserDefaults; the Keychain keeps it out
/// of backups and plain-text preference files. "After first unlock" access is required because
/// the sensor wakes Loop in the background while the phone is locked.
final class DirectConnect_KeychainKeyStore: DirectConnect_KeyStoring {
    static let service = "com.loopkit.Loop.DirectConnect"
    private static let slots: [UInt8] = [1, 2, 3]

    private func account(_ sensor: String, _ slot: UInt8) -> String {
        "\(sensor).\(String(format: "%02X", slot))"
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
    }

    func key(sensor: String, slot: UInt8) -> Data? {
        var query = baseQuery(account(sensor, slot))
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, data.count == 16 else {
            return nil
        }
        return data
    }

    func save(_ key: Data, sensor: String, slot: UInt8) {
        let query = baseQuery(account(sensor, slot))
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = key
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func delete(sensor: String) {
        for slot in Self.slots {
            SecItemDelete(baseQuery(account(sensor, slot)) as CFDictionary)
        }
    }
}

/// In-memory store for unit tests.
final class DirectConnect_MemoryKeyStore: DirectConnect_KeyStoring {
    private var keys: [String: Data] = [:]
    private let lock = NSLock()

    func key(sensor: String, slot: UInt8) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return keys["\(sensor).\(slot)"]
    }

    func save(_ key: Data, sensor: String, slot: UInt8) {
        lock.lock(); defer { lock.unlock() }
        keys["\(sensor).\(slot)"] = key
    }

    func delete(sensor: String) {
        lock.lock(); defer { lock.unlock() }
        keys = keys.filter { !$0.key.hasPrefix("\(sensor).") }
    }
}
