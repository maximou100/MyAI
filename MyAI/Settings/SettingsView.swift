//
//  SettingsView.swift
//  MyAI
//
//  The "Settings" tab. Sections for the foundation model, knowledge, agents,
//  skills, and an About footer with version and author.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(LLMEngine.self) private var engine
    @Environment(SettingsStore.self) private var settings

    @Query private var knowledge: [KnowledgeFile]
    @Query private var agents: [Agent]
    @Query private var skills: [Skill]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    availabilityRow
                }

                Section("Intelligence") {
                    NavigationLink {
                        FoundationModelSettingsView()
                    } label: {
                        Label("Apple Foundation Model", systemImage: "apple.logo")
                    }
                }

                Section("Customization") {
                    NavigationLink {
                        KnowledgeFilesView()
                    } label: {
                        settingRow("Knowledge Files", systemImage: "books.vertical", count: knowledge.count)
                    }
                    NavigationLink {
                        AgentsView()
                    } label: {
                        settingRow("Agents", systemImage: "person.2.badge.gearshape", count: agents.count)
                    }
                    NavigationLink {
                        SkillsView()
                    } label: {
                        settingRow("Skills", systemImage: "wand.and.stars", count: skills.count)
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: settings.isCloudSyncAvailable ? "icloud.fill" : "icloud.slash")
                            .foregroundStyle(settings.isCloudSyncAvailable ? .blue : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.isCloudSyncAvailable ? "Syncing with iCloud" : "iCloud unavailable")
                                .font(.subheadline.weight(.medium))
                            Text(settings.isCloudSyncAvailable
                                 ? "Chats, agents, skills, knowledge, and settings stay in sync across your devices."
                                 : "Sign in to iCloud in Settings to sync your chats, agents, skills, knowledge, and settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("iCloud")
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                } footer: {
                    AboutFooter()
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var availabilityRow: some View {
        HStack(spacing: 12) {
            Image(systemName: engine.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(engine.isAvailable ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.isAvailable ? "Ready" : "Unavailable")
                    .font(.headline)
                Text(engine.availabilityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func settingRow(_ title: String, systemImage: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
    }
}

/// Compact version + author line used in the Settings footer.
struct AboutFooter: View {
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text("MyAI \(AppInfo.versionString)")
            Text("Maxime Leclercq")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// Convenience accessors for bundle version information.
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    static var versionString: String { "v\(version) (\(build))" }
}
