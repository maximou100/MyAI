//
//  MyAIApp.swift
//  MyAI
//
//  Created by Maxime LECLERCQ on 8/10/26.
//

import SwiftUI
import SwiftData

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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            SampleData.seedIfNeeded(container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
