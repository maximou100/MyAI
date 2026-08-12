//
//  CloudKitSchema.swift
//  MyAI
//
//  One-time helper that pushes the SwiftData schema to the CloudKit
//  *development* environment.
//
//  CloudKit needs record types to exist before it can sync. During development
//  they're created lazily, but you must publish a complete schema before
//  promoting to production — and CloudKit schemas are additive only, so record
//  types and fields can't be changed once promoted.
//
//  This runs only in DEBUG, and only when launched with the
//  "-InitializeCloudKitSchema" argument, so it never slows normal launches:
//
//    Product > Scheme > Edit Scheme > Run > Arguments
//    add "-InitializeCloudKitSchema", run once, then remove it.
//
//  Afterwards verify the record types at https://icloud.developer.apple.com
//

import Foundation
import SwiftData
import OSLog

#if DEBUG
import CoreData

enum CloudKitSchema {

    static let containerIdentifier = "iCloud.Max-Leclercq.MyAI"

    /// Whether a schema push was requested.
    ///
    /// Accepts either form, since Xcode's scheme editor offers both and it's
    /// easy to add one where you meant the other:
    ///   - launch argument:      `-InitializeCloudKitSchema`
    ///   - environment variable: `InitializeCloudKitSchema` (any value except 0/NO/false)
    static var isRequested: Bool {
        if CommandLine.arguments.contains("-InitializeCloudKitSchema") {
            return true
        }
        guard let value = ProcessInfo.processInfo.environment["InitializeCloudKitSchema"] else {
            return false
        }
        let disabled = ["0", "no", "false"]
        return !disabled.contains(value.lowercased())
    }

    /// Publishes the schema to CloudKit's development environment.
    ///
    /// Loads the same on-disk store through Core Data, initializes the schema,
    /// then unloads it so SwiftData and Core Data never sync concurrently.
    static func initializeIfRequested(schema: Schema) {
        guard isRequested else { return }

        let log = Logger(subsystem: "Max-Leclercq.MyAI", category: "cloudkit-schema")

        // Publishing the schema talks to iCloud, so it needs a signed-in
        // account. The Simulator usually has none — run this on a real device.
        guard FileManager.default.ubiquityIdentityToken != nil else {
            log.error("""
                Schema push skipped: no iCloud account on this device. \
                Run on a device signed in to iCloud, or sign in via \
                Settings in the Simulator.
                """)
            return
        }

        log.info("Publishing CloudKit development schema for \(containerIdentifier, privacy: .public)…")
        let configuration = ModelConfiguration(schema: schema)

        do {
            // Deallocate the Core Data stack before SwiftData builds its own.
            try autoreleasepool {
                let description = NSPersistentStoreDescription(url: configuration.url)
                description.cloudKitContainerOptions =
                    NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
                // Load synchronously so the store is ready before initializing.
                description.shouldAddStoreAsynchronously = false

                guard let model = NSManagedObjectModel.makeManagedObjectModel(
                    for: [Conversation.self, Message.self, KnowledgeFile.self, Agent.self, Skill.self]
                ) else {
                    log.error("Could not build a managed object model for the schema.")
                    return
                }

                let container = NSPersistentCloudKitContainer(name: "MyAI", managedObjectModel: model)
                container.persistentStoreDescriptions = [description]
                var loadError: Error?
                container.loadPersistentStores { _, error in loadError = error }
                if let loadError { throw loadError }

                try container.initializeCloudKitSchema()

                if let store = container.persistentStoreCoordinator.persistentStores.first {
                    try container.persistentStoreCoordinator.remove(store)
                }
            }
            log.info("CloudKit development schema initialized. Promote it in the CloudKit Console.")
        } catch {
            log.error("CloudKit schema initialization failed: \(error, privacy: .public)")
        }
    }
}
#endif
