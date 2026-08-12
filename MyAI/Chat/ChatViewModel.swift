//
//  ChatViewModel.swift
//  MyAI
//
//  Drives a single conversation: composes instructions, maintains the model
//  session for multi-turn context, and streams responses into SwiftData.
//

import Foundation
import Observation
import SwiftData
import FoundationModels
import UIKit
import OSLog

extension Logger {
    static let chat = Logger(subsystem: "Max-Leclercq.MyAI", category: "chat")
}

/// A file or image the user attached to their next message with the "+" button.
struct PendingAttachment: Equatable {
    enum Kind: Equatable {
        /// Text extracted from a document, folded into the prompt.
        case text(String)
        /// Image data sent to the model as a real multimodal attachment.
        case image(Data)
    }

    var name: String
    var kind: Kind

    var imageData: Data? {
        if case let .image(data) = kind { return data }
        return nil
    }

    var textContent: String? {
        if case let .text(text) = kind { return text }
        return nil
    }
}

@MainActor
@Observable
final class ChatViewModel {

    var isResponding = false
    var errorMessage: String?

    private var session: LanguageModelSession?
    private var boundConversationID: UUID?
    private var boundInstructions: String?

    /// Forces the next send to rebuild the session (e.g. after switching chats).
    /// Also clears any stale error so it doesn't follow the user into a new chat.
    func resetSession() {
        session = nil
        boundConversationID = nil
        boundInstructions = nil
        errorMessage = nil
    }

    func send(
        userText: String,
        attachment: PendingAttachment?,
        conversation: Conversation,
        agent: Agent?,
        skills: [Skill],
        knowledge: [KnowledgeFile],
        settings: SettingsStore,
        engine: LLMEngine,
        context: ModelContext
    ) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachment != nil else { return }

        guard engine.isAvailable else {
            errorMessage = engine.availabilityDescription
            return
        }

        // Persist the user's message, keeping any image so the thread can show it.
        let userMessage = Message(
            role: .user,
            text: trimmed,
            attachmentName: attachment?.name,
            attachmentImageData: attachment?.imageData
        )
        userMessage.conversation = conversation
        context.insert(userMessage)
        conversation.updatedAt = .now
        if conversation.title == "New Chat" {
            conversation.title = Self.deriveTitle(from: trimmed.isEmpty ? (attachment?.name ?? "New Chat") : trimmed)
        }

        // Compose instructions and (re)build the session if anything changed.
        let instructions = PromptComposer.instructions(
            settings: settings,
            agent: agent,
            skills: skills,
            knowledge: knowledge
        )
        let entries = knowledge
            .filter { $0.isActive }
            .map { KnowledgeEntry(title: $0.title, content: $0.content) }

        if session == nil || boundConversationID != conversation.id || boundInstructions != instructions {
            session = engine.makeSession(
                instructions: instructions,
                knowledge: entries,
                useTool: settings.enableKnowledgeTool,
                settings: settings
            )
            boundConversationID = conversation.id
            boundInstructions = instructions
        }

        // Assemble the prompt. Text files are folded in; images become a real
        // multimodal attachment the model can look at directly.
        var promptText = trimmed
        if let text = attachment?.textContent, let name = attachment?.name {
            promptText += "\n\n[Attached file: \(name)]\n\(text)"
        }
        if promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptText = "Describe this image."
        }
        let image = attachment?.imageData.flatMap { UIImage(data: $0) }
        let prompt = engine.makePrompt(text: promptText, image: image)

        // Create the assistant message we'll stream into.
        let assistant = Message(role: .assistant, text: "")
        assistant.conversation = conversation
        context.insert(assistant)

        isResponding = true
        errorMessage = nil
        defer { isResponding = false }

        do {
            let options = engine.makeOptions(settings: settings, temperatureOverride: agent?.temperature)
            let stream = session!.streamResponse(to: prompt, options: options)
            for try await snapshot in stream {
                assistant.text = snapshot.content
            }
            if assistant.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                assistant.text = "_(The model returned an empty response.)_"
            }
        } catch {
            context.delete(assistant)
            // Drop the stale session first — resetSession() clears errorMessage,
            // so the message has to be assigned after it.
            resetSession()
            errorMessage = Self.friendlyMessage(for: error)
        }

        conversation.updatedAt = .now
        try? context.save()
    }

    // MARK: - Helpers

    private static func deriveTitle(from text: String) -> String {
        let firstLine = text.split(separator: "\n").first.map(String.init) ?? text
        let clipped = firstLine.prefix(42)
        return clipped.count < firstLine.count ? "\(clipped)…" : String(clipped)
    }

    private static func friendlyMessage(for error: Error) -> String {
        // Private Cloud Compute reports its own error type.
        if let pccError = error as? PrivateCloudComputeLanguageModel.Error {
            switch pccError {
            case .networkFailure:
                return "Private Cloud Compute needs a network connection. Check your connection and try again."
            case .quotaLimitReached:
                return "You've reached your Private Cloud Compute usage limit. Turn it off in Settings to keep using the on-device model."
            case .serviceUnavailable:
                return "Private Cloud Compute is temporarily unavailable. Try again later."
            @unknown default:
                return "Private Cloud Compute couldn't complete that request."
            }
        }
        if let modelError = error as? LanguageModelError {
            switch modelError {
            case .contextSizeExceeded:
                return "This conversation got too long for the model's context window. Start a new chat to continue."
            case .unsupportedLanguageOrLocale:
                return "That language isn't supported by Apple Intelligence yet."
            case .rateLimited:
                return "The model is busy right now. Please try again in a moment."
            case .guardrailViolation:
                return "The request was blocked by the model's safety guardrails."
            case .unsupportedCapability:
                return "The selected model doesn't support that capability."
            default:
                return "The model couldn't complete that request. Please try again."
            }
        }

        // Anything else (for example a missing model-catalog asset) is a system-level
        // failure. Log the detail but keep the raw NSError dump out of the UI.
        Logger.chat.error("Generation failed: \(error, privacy: .public)")
        let description = String(describing: error).lowercased()
        if description.contains("modelcatalog") || description.contains("asset") {
            return "The on-device model isn't ready yet — its assets are still downloading, or Apple Intelligence isn't fully set up on this device."
        }
        return "Something went wrong talking to the model. Please try again."
    }
}
