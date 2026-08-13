//
//  SkillsView.swift
//  MyAI
//
//  Create and manage reusable skills. Enabled skills shape every response.
//  Supports manual editing plus .md import/export.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SkillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Skill.createdAt) private var skills: [Skill]

    @State private var editing: Skill?
    @State private var showImporter = false
    @State private var exportDoc: MarkdownDocument?
    @State private var exportName = "Skill"
    @State private var showExporter = false

    var body: some View {
        List {
            Section {
                LabeledContent("Skills in use") {
                    Text("\(skills.filter(\.isEnabled).count) of \(skills.count)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("In Use")
            } footer: {
                Text("Enabled skills are added to the model's instructions so it applies them whenever they're relevant. Toggle a skill below to turn it on or off.")
            }

            ForEach(skills) { skill in
                HStack {
                    Button {
                        editing = skill
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if !skill.summary.isEmpty {
                                Text(skill.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    // Without this the button tints its whole label blue,
                    // flattening the title/summary hierarchy.
                    .buttonStyle(.plain)
                    Spacer()
                    Toggle("", isOn: enabledBinding(for: skill))
                        .labelsHidden()
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        export(skill)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: delete)
        }
        .overlay {
            if skills.isEmpty {
                ContentUnavailableView("No skills yet",
                                       systemImage: "wand.and.stars",
                                       description: Text("Create a skill or import one from a Markdown file."))
            }
        }
        .navigationTitle("Skills")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let skill = Skill(name: "New Skill", content: "")
                        modelContext.insert(skill)
                        editing = skill
                    } label: {
                        Label("New Skill", systemImage: "plus")
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
        .sheet(item: $editing) { skill in
            SkillEditor(skill: skill)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [MarkdownDocument.markdownType, .plainText, .text],
            allowsMultipleSelection: true
        ) { result in
            importSkills(result)
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDoc,
            contentType: MarkdownDocument.markdownType,
            defaultFilename: exportName
        ) { _ in }
    }

    private func enabledBinding(for skill: Skill) -> Binding<Bool> {
        Binding(
            get: { skill.isEnabled },
            set: { newValue in
                skill.isEnabled = newValue
                try? modelContext.save()
            }
        )
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(skills[index])
        }
        try? modelContext.save()
    }

    private func export(_ skill: Skill) {
        exportDoc = MarkdownDocument(text: MarkdownConverter.markdown(for: skill))
        exportName = skill.name
        showExporter = true
    }

    private func importSkills(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result else { return }
        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let fallback = url.deletingPathExtension().lastPathComponent
            let parsed = MarkdownConverter.parseSkill(text, fallbackName: fallback)
            modelContext.insert(Skill(name: parsed.name, summary: parsed.summary, content: parsed.content))
        }
        try? modelContext.save()
    }
}

/// Manual editor for a single skill.
private struct SkillEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var skill: Skill

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $skill.name)
                }
                Section("Summary") {
                    TextField("Short description", text: $skill.summary, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section("Instructions") {
                    TextEditor(text: $skill.content)
                        .frame(minHeight: 220)
                        .font(.callout)
                }
                Section {
                    Toggle("Enabled", isOn: $skill.isEnabled)
                }
            }
            .navigationTitle("Edit Skill")
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
