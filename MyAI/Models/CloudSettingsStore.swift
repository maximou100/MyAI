//
//  CloudSettingsStore.swift
//  MyAI
//
//  Mirrors app settings into iCloud's key-value store so preferences follow the
//  person between devices.
//
//  SwiftData handles syncing the *content* (chats, agents, skills, knowledge)
//  through CloudKit, but plain preferences live in UserDefaults, which doesn't
//  sync on its own. NSUbiquitousKeyValueStore covers that gap: it's built for
//  small amounts of preference data and needs the same iCloud entitlement.
//

import Foundation
import OSLog

/// A write-through cache over `UserDefaults` and `NSUbiquitousKeyValueStore`.
///
/// Reads come from `UserDefaults` so the app always has an immediate local
/// answer. Writes go to both. When iCloud pushes a change from another device,
/// the new values are copied into `UserDefaults` and a notification is posted so
/// observers can refresh.
final class CloudSettingsStore {

    static let shared = CloudSettingsStore()

    /// Posted after values arrive from another device.
    static let didChangeExternally = Notification.Name("CloudSettingsStore.didChangeExternally")

    private let defaults = UserDefaults.standard
    private let cloud = NSUbiquitousKeyValueStore.default
    private let log = Logger(subsystem: "Max-Leclercq.MyAI", category: "cloud-settings")

    /// Keys this store mirrors. Anything not listed stays device-local.
    private var mirroredKeys: Set<String> = []

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        cloud.synchronize()
    }

    /// Whether the device currently has an iCloud account available for syncing.
    var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Registration

    /// Registers keys for mirroring and pulls down any newer iCloud values.
    ///
    /// Called once at startup with every key the settings store owns.
    func register(keys: [String]) {
        mirroredKeys.formUnion(keys)
        pullFromCloud(keys: keys)
    }

    // MARK: - Write-through

    func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
        guard mirroredKeys.contains(key) else { return }
        if let value {
            cloud.set(value, forKey: key)
        } else {
            cloud.removeObject(forKey: key)
        }
    }

    // MARK: - Incoming changes

    @objc private func cloudDidChange(_ note: Notification) {
        let info = note.userInfo
        let reason = info?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int

        // A quota violation means nothing new arrived; ignore it.
        if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            log.warning("iCloud key-value quota exceeded; settings not synced.")
            return
        }

        let changed = info?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        pullFromCloud(keys: changed ?? Array(mirroredKeys))

        NotificationCenter.default.post(name: Self.didChangeExternally, object: nil)
    }

    /// Copies iCloud values into `UserDefaults` for the given keys.
    private func pullFromCloud(keys: [String]) {
        for key in keys where mirroredKeys.contains(key) {
            guard let value = cloud.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
        }
    }
}
