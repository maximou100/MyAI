//
//  ContentView.swift
//  MyAI
//
//  Root of the app: two tabs — the MyAI chat and Settings.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("MyAI", systemImage: "bubble.left.and.bubble.right.fill") {
                ChatHomeView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(SettingsStore())
        .environment(LLMEngine())
        .modelContainer(for: [Conversation.self, Message.self, KnowledgeFile.self, Agent.self, Skill.self], inMemory: true)
}
