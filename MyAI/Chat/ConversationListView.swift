//
//  ConversationListView.swift
//  MyAI
//
//  History sheet listing past conversations.
//

import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var selected: Conversation?
    /// Called when the selection changes so the chat view can reset its session.
    var onSelectionChange: () -> Void

    @Query(sort: \Conversation.updatedAt, order: .reverse) private var allConversations: [Conversation]

    /// Empty chats aren't worth listing — they carry no content to return to.
    private var conversations: [Conversation] {
        allConversations.filter { !$0.messages.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(conversations) { conversation in
                    Button {
                        selected = conversation
                        onSelectionChange()
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(.headline)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            HStack {
                                Text("^[\(conversation.messages.count) message](inflect: true)")
                                Spacer()
                                Text(conversation.updatedAt, format: .relative(presentation: .named))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if conversations.isEmpty {
                    ContentUnavailableView("No conversations yet", systemImage: "bubble.left")
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            let convo = conversations[index]
            if convo.id == selected?.id {
                selected = nil
            }
            modelContext.delete(convo)
        }
        try? modelContext.save()
    }
}
