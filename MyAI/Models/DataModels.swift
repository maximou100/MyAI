//
//  DataModels.swift
//  MyAI
//
//  SwiftData models that back the chat, knowledge base, agents, and skills.
//
//  These models sync to iCloud via CloudKit, which constrains the schema:
//  every stored property needs a default value, every relationship must be
//  optional, and unique constraints aren't supported. See
//  https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
//

import Foundation
import SwiftData

/// The author of a chat message.
enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case system
}

/// A single chat conversation, ChatGPT style.
@Model
final class Conversation {
    var id: UUID = UUID()
    var title: String = "New Chat"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Optional agent this conversation is bound to.
    var agentID: UUID?

    /// Optional for CloudKit: iCloud can't guarantee atomic relationship updates.
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]?

    init(title: String = "New Chat", agentID: UUID? = nil, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.agentID = agentID
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.messages = []
    }

    /// Messages sorted oldest-first for display.
    var sortedMessages: [Message] {
        (messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// Number of messages, tolerating the optional relationship.
    var messageCount: Int { messages?.count ?? 0 }

    var isEmpty: Bool { messageCount == 0 }
}

/// A single message inside a conversation.
@Model
final class Message {
    var id: UUID = UUID()
    /// Stored as a raw string to keep SwiftData migrations simple.
    var roleRaw: String = MessageRole.assistant.rawValue
    var text: String = ""
    var createdAt: Date = Date()
    /// The name of an attached file, if the user added one with the "+" button.
    var attachmentName: String?
    /// Encoded image data when the attachment is a picture, so it can be shown in the thread.
    @Attribute(.externalStorage) var attachmentImageData: Data?
    var conversation: Conversation?

    init(
        role: MessageRole,
        text: String,
        attachmentName: String? = nil,
        attachmentImageData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.text = text
        self.attachmentName = attachmentName
        self.attachmentImageData = attachmentImageData
        self.createdAt = createdAt
    }

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .assistant }
        set { roleRaw = newValue.rawValue }
    }
}

/// A piece of user-authored knowledge the model can reason over.
@Model
final class KnowledgeFile {
    var id: UUID = UUID()
    var title: String = "Untitled"
    var content: String = ""
    /// When active, the content is made available to the model.
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(title: String, content: String, isActive: Bool = true, createdAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

/// A configurable agent: a named persona with its own instructions and settings.
@Model
final class Agent {
    var id: UUID = UUID()
    var name: String = "New Agent"
    var summary: String = ""
    var instructions: String = ""
    /// Per-agent creativity override in the range 0...1.
    var temperature: Double = 0.7
    var createdAt: Date = Date()

    init(name: String, summary: String = "", instructions: String, temperature: Double = 0.7, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.summary = summary
        self.instructions = instructions
        self.temperature = temperature
        self.createdAt = createdAt
    }
}

/// A reusable skill: focused guidance that can be toggled on to shape responses.
@Model
final class Skill {
    var id: UUID = UUID()
    var name: String = "New Skill"
    var summary: String = ""
    var content: String = ""
    var isEnabled: Bool = false
    var createdAt: Date = Date()

    init(name: String, summary: String = "", content: String, isEnabled: Bool = false, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.summary = summary
        self.content = content
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}
