//
//  ChatHomeView.swift
//  MyAI
//
//  The "MyAI" tab: a ChatGPT-style conversation with model options and file attach.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

struct ChatHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(LLMEngine.self) private var engine

    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \Agent.createdAt) private var agents: [Agent]
    @Query private var skills: [Skill]
    @Query private var knowledge: [KnowledgeFile]

    @State private var viewModel = ChatViewModel()
    @State private var current: Conversation?
    @State private var draft = ""
    @State private var attachment: PendingAttachment?
    @State private var showHistory = false
    @State private var showImporter = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @FocusState private var isInputFocused: Bool

    private var resolvedAgent: Agent? {
        agents.first { $0.id.uuidString == settings.selectedAgentID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let current {
                    ChatThread(
                        conversation: current,
                        isResponding: viewModel.isResponding,
                        errorMessage: viewModel.errorMessage,
                        unavailableMessage: engine.isAvailable ? nil : engine.availabilityDescription,
                        onDismissKeyboard: { isInputFocused = false }
                    )
                } else {
                    ContentUnavailableView("Start a conversation", systemImage: "bubble.left.and.bubble.right")
                }
            }
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(
                    text: $draft,
                    attachment: $attachment,
                    isResponding: viewModel.isResponding,
                    isEnabled: engine.isAvailable,
                    isFocused: $isInputFocused,
                    onAttach: { showImporter = true },
                    onAttachPhoto: { showPhotoPicker = true },
                    onSend: sendMessage
                )
            }
            .navigationTitle(current?.title ?? "MyAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showHistory) {
                ConversationListView(selected: $current) { viewModel.resetSession() }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.plainText, .text, .json, .commaSeparatedText, .rtf, .pdf, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }
                Task { await loadPhoto(newValue) }
            }
        }
        .onAppear(perform: ensureConversation)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .accessibilityLabel("Chat history")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Model") {
                    Label("Apple Intelligence (On-Device)", systemImage: "apple.logo")
                }
                Picker("Agent", selection: agentSelection) {
                    Text("Default Assistant").tag("")
                    ForEach(agents) { agent in
                        Text(agent.name).tag(agent.id.uuidString)
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel("Model options")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: newConversation) {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel("New chat")
        }
    }

    private var agentSelection: Binding<String> {
        Binding(
            get: { settings.selectedAgentID },
            set: { newValue in
                settings.selectedAgentID = newValue
                viewModel.resetSession()
            }
        )
    }

    // MARK: - Actions

    private func ensureConversation() {
        if current == nil {
            current = conversations.first ?? makeConversation()
        }
    }

    private func makeConversation() -> Conversation {
        let convo = Conversation(agentID: resolvedAgent?.id)
        modelContext.insert(convo)
        try? modelContext.save()
        return convo
    }

    private func newConversation() {
        // Reuse the current chat if it's still empty instead of piling up blank
        // conversations in History.
        if current?.messages.isEmpty == true {
            current?.updatedAt = .now
        } else {
            current = makeConversation()
        }
        viewModel.resetSession()
        draft = ""
        attachment = nil
    }

    private func sendMessage() {
        guard let conversation = current else { return }
        let text = draft
        let file = attachment
        draft = ""
        attachment = nil

        Task {
            await viewModel.send(
                userText: text,
                attachment: file,
                conversation: conversation,
                agent: resolvedAgent,
                skills: skills,
                knowledge: knowledge,
                settings: settings,
                engine: engine,
                context: modelContext
            )
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent

        // Images become real multimodal attachments; everything else is read as text.
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           type.conforms(to: .image),
           let data = try? Data(contentsOf: url) {
            attachment = PendingAttachment(name: name, kind: .image(data))
            return
        }

        if let text = try? String(contentsOf: url, encoding: .utf8) {
            attachment = PendingAttachment(name: name, kind: .text(String(text.prefix(20_000))))
        } else {
            // Non-text file: still reference it by name so the user sees the attachment.
            attachment = PendingAttachment(
                name: name,
                kind: .text("(Binary file — contents not readable as text.)")
            )
        }
    }

    /// Loads the picked photo into a pending image attachment.
    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let name = item.itemIdentifier.map { "Photo \($0.prefix(6))" } ?? "Photo"
        attachment = PendingAttachment(name: name, kind: .image(data))
        photoItem = nil
    }
}

/// The scrolling list of messages for a single conversation.
private struct ChatThread: View {
    let conversation: Conversation
    let isResponding: Bool
    let errorMessage: String?
    let unavailableMessage: String?
    let onDismissKeyboard: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if let unavailableMessage {
                        banner(unavailableMessage, systemImage: "exclamationmark.triangle", tint: .orange)
                    }

                    if conversation.messages.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    }

                    ForEach(conversation.sortedMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Errors relate to the most recent send, so they belong after it.
                    if let errorMessage {
                        banner(errorMessage, systemImage: "xmark.octagon", tint: .red)
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding()
            }
            // Scrolling or tapping the transcript dismisses the keyboard, which
            // otherwise covers the tab bar with no way out.
            .scrollDismissesKeyboard(.immediately)
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismissKeyboard)
            .onChange(of: conversation.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: lastMessageText) { _, _ in scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy) }
        }
    }

    private let bottomAnchor = "bottom-anchor"

    private var lastMessageText: String {
        conversation.sortedMessages.last?.text ?? ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("How can I help?")
                .font(.title2.weight(.semibold))
            Text("Ask a question, or tap + to attach a file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func banner(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(tint)
    }
}
