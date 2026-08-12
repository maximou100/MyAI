//
//  KnowledgeFilesView.swift
//  MyAI
//
//  Manage knowledge entries the model can reason over. Active entries are made
//  available to the model (inline and/or via the knowledge search tool).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct KnowledgeFilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgeFile.createdAt, order: .reverse) private var files: [KnowledgeFile]

    @State private var editing: KnowledgeFile?
    @State private var showImporter = false

    var body: some View {
        List {
            Section {
                Text("Active knowledge is provided to the model so it can ground its answers in your own data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(files) { file in
                Button {
                    editing = file
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(file.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if file.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        file.isActive.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(file.isActive ? "Deactivate" : "Activate",
                              systemImage: file.isActive ? "pause" : "play")
                    }
                    .tint(file.isActive ? .gray : .green)
                }
            }
            .onDelete(perform: delete)
        }
        .overlay {
            if files.isEmpty {
                ContentUnavailableView("No knowledge yet",
                                       systemImage: "books.vertical",
                                       description: Text("Add facts, notes, or reference data for the model to use."))
            }
        }
        .navigationTitle("Knowledge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let file = KnowledgeFile(title: "Untitled", content: "")
                        modelContext.insert(file)
                        editing = file
                    } label: {
                        Label("New Entry", systemImage: "plus")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Text File", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editing) { file in
            KnowledgeEditor(file: file)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText, .text, .json, .commaSeparatedText],
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(files[index])
        }
        try? modelContext.save()
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result else { return }
        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let title = url.deletingPathExtension().lastPathComponent
            modelContext.insert(KnowledgeFile(title: title, content: text))
        }
        try? modelContext.save()
    }
}

/// Editor sheet for a single knowledge entry.
private struct KnowledgeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var file: KnowledgeFile

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $file.title)
                }
                Section("Content") {
                    TextEditor(text: $file.content)
                        .frame(minHeight: 220)
                        .font(.callout)
                }
                Section {
                    Toggle("Active", isOn: $file.isActive)
                }
            }
            .navigationTitle("Knowledge Entry")
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
