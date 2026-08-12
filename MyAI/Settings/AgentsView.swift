//
//  AgentsView.swift
//  MyAI
//
//  Create agents with open configuration, and import/export them as .md files.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AgentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \Agent.createdAt) private var agents: [Agent]

    @State private var editing: Agent?
    @State private var showImporter = false
    @State private var exportDoc: MarkdownDocument?
    @State private var exportName = "Agent"
    @State private var showExporter = false

    var body: some View {
        @Bindable var settings = settings

        return List {
            Section {
                Picker("Active agent", selection: $settings.selectedAgentID) {
                    Text("Default Assistant").tag("")
                    ForEach(agents) { agent in
                        Text(agent.name).tag(agent.id.uuidString)
                    }
                }
            } header: {
                Text("In Use")
            } footer: {
                Text("The active agent replaces the default instructions for every new message. You can also switch agents from the chat's options menu.")
            }

            Section("All Agents") {
                ForEach(agents) { agent in
                    agentRow(agent)
                }
                .onDelete(perform: delete)
            }
        }
        .overlay {
            if agents.isEmpty {
                ContentUnavailableView("No agents yet",
                                       systemImage: "person.2.badge.gearshape",
                                       description: Text("Create an agent or import one from a Markdown file."))
            }
        }
        .navigationTitle("Agents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(item: $editing) { agent in
            AgentEditor(agent: agent)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [MarkdownDocument.markdownType, .plainText, .text],
            allowsMultipleSelection: true
        ) { result in
            importAgents(result)
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDoc,
            contentType: MarkdownDocument.markdownType,
            defaultFilename: exportName
        ) { _ in }
    }

    private func agentRow(_ agent: Agent) -> some View {
        let isActive = settings.selectedAgentID == agent.id.uuidString
        return Button {
            editing = agent
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !agent.summary.isEmpty {
                        Text(agent.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if isActive {
                    Text("In use")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                settings.selectedAgentID = isActive ? "" : agent.id.uuidString
            } label: {
                Label(isActive ? "Stop using" : "Use", systemImage: isActive ? "person.slash" : "person.fill.checkmark")
            }
            .tint(isActive ? .gray : .accentColor)
        }
        .swipeActions(edge: .trailing) {
            Button {
                export(agent)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    let agent = Agent(name: "New Agent",
                                      instructions: "You are a helpful assistant.")
                    modelContext.insert(agent)
                    editing = agent
                } label: {
                    Label("New Agent", systemImage: "plus")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Import .md", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(agents[index])
        }
        try? modelContext.save()
    }

    private func export(_ agent: Agent) {
        exportDoc = MarkdownDocument(text: MarkdownConverter.markdown(for: agent))
        exportName = agent.name
        showExporter = true
    }

    private func importAgents(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result else { return }
        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let fallback = url.deletingPathExtension().lastPathComponent
            let parsed = MarkdownConverter.parseAgent(text, fallbackName: fallback)
            modelContext.insert(Agent(
                name: parsed.name,
                summary: parsed.summary,
                instructions: parsed.instructions,
                temperature: parsed.temperature
            ))
        }
        try? modelContext.save()
    }
}

/// Open configuration editor for an agent.
private struct AgentEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var agent: Agent

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $agent.name)
                }
                Section("Summary") {
                    TextField("Short description", text: $agent.summary, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section("Instructions") {
                    TextEditor(text: $agent.instructions)
                        .frame(minHeight: 200)
                        .font(.callout)
                }
                Section("Creativity") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.2f", agent.temperature))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $agent.temperature, in: 0...1, step: 0.05)
                    }
                }
            }
            .navigationTitle("Configure Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
