//
//  ChatComponents.swift
//  MyAI
//
//  Reusable pieces of the chat UI: message bubbles and the input bar.
//

import SwiftUI

/// A single chat bubble, styled by role.
struct MessageBubble: View {
    let message: Message

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let data = message.attachmentImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if let attachment = message.attachmentName {
                    Label(attachment, systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if message.text.isEmpty {
                    // Streaming placeholder before the first token arrives.
                    ProgressView()
                        .padding(.vertical, 4)
                } else {
                    Text(markdown(message.text))
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            Color.accentColor.opacity(0.18)
        } else {
            Color(.secondarySystemBackground)
        }
    }

    /// Renders Markdown when possible, falling back to plain text.
    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// The bottom composer bar with a "+" attach button and a send button.
struct ChatInputBar: View {
    @Binding var text: String
    @Binding var attachment: PendingAttachment?
    var isResponding: Bool
    var isEnabled: Bool
    /// Owned by the chat screen so tapping the transcript can dismiss the keyboard.
    @FocusState.Binding var isFocused: Bool
    var onAttach: () -> Void
    var onAttachPhoto: () -> Void
    var onSend: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let attachment {
                HStack {
                    if let data = attachment.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    Label(attachment.name, systemImage: attachment.imageData == nil ? "doc.text" : "photo")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        self.attachment = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground), in: Capsule())
            }

            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    Button {
                        onAttachPhoto()
                    } label: {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        onAttach()
                    } label: {
                        Label("File", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Attach a photo or file")

                TextField("Message MyAI…", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    isFocused = false
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .symbolEffect(.pulse, isActive: isResponding)
                }
                .disabled(!canSend)
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSend: Bool {
        guard isEnabled, !isResponding else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil
    }
}
