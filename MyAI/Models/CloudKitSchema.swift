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

    /// Whether the launch argument asked for a schema push.
    static var isRequested: Bool {
        CommandLine.arguments.contains("-InitializeCloudKitSchema")
    }

    /// Publishes the schema to CloudKit's development environment.
    ///
    /// Loads the same on-disk store through Core Data, initializes the schema,
    /// then unloads it so SwiftData and Core Data never sync concurrently.
    static func initializeIfRequested(schema: Schema) {
        guard isRequested else { return }

        let log = Logger(subsystem: "Max-Leclercq.MyAI", category: "cloudkit-schema")
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
