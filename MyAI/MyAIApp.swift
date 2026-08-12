//
//  MyAIApp.swift
//  MyAI
//
//  Created by Maxime LECLERCQ on 8/10/26.
//

import SwiftUI
import SwiftData
import OSLog

extension Logger {
    static let app = Logger(subsystem: "Max-Leclercq.MyAI", category: "app")
}

@main
struct MyAIApp: App {
    @State private var settings = SettingsStore()
    @State private var engine = LLMEngine()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            Message.self,
            KnowledgeFile.self,
            Agent.self,
            Skill.self,
        ])
        // `.automatic` reads the app's entitlements: with the iCloud/CloudKit
        // capability present, SwiftData syncs chats, agents, skills, and
        // knowledge across the person's devices. Without it, everything stays
        // local and this is a no-op.
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfiguration])
            SampleData.seedIfNeeded(container.mainContext)
            return container
        } catch {
            // Never trap on a sync problem — a missing container, a signed-out
            // iCloud account, or a schema CloudKit rejects would otherwise make
            // the app unlaunchable. Fall back to local-only storage instead.
            Logger.app.error("CloudKit-backed store failed, falling back to local: \(error, privacy: .public)")
            do {
                let localConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: [localConfiguration])
                SampleData.seedIfNeeded(container.mainContext)
                return container
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(engine)
        }
        .modelContainer(sharedModelContainer)
    }
}
