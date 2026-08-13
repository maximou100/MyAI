//
//  LLMEngine.swift
//  MyAI
//
//  Thin wrapper around Apple's on-device Foundation model (FoundationModels).
//  Handles availability, instruction composition, an optional knowledge tool,
//  and streaming responses.
//

import Foundation
import Observation
import FoundationModels
import Vision
import UIKit
import ImageIO

/// A lightweight, Sendable snapshot of a knowledge entry used by the tool.
struct KnowledgeEntry: Sendable {
    let title: String
    let content: String
}

/// A tool that lets the model search the user's knowledge base at runtime.
struct KnowledgeLookupTool: Tool {
    let name = "searchKnowledge"
    let description = "Search the user's personal knowledge base for facts and context that help answer the question."

    let entries: [KnowledgeEntry]

    @Generable
    struct Arguments {
        @Guide(description: "Keywords or a question to look up in the knowledge base.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard !entries.isEmpty else {
            return "The knowledge base is empty."
        }
        let terms = arguments.query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 }

        // Score each entry by how many query terms it mentions.
        let scored = entries.map { entry -> (KnowledgeEntry, Int) in
            let haystack = (entry.title + " " + entry.content).lowercased()
            let score = terms.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
            return (entry, score)
        }

        let matches = scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0.0 }

        let selected = matches.isEmpty ? Array(entries.prefix(2)) : Array(matches)
        return selected
            .map { "## \($0.title)\n\($0.content)" }
            .joined(separator: "\n\n")
    }
}

/// Composes system instructions from settings, an agent, skills, and knowledge.
enum PromptComposer {

    /// Maximum characters of knowledge injected inline to protect the context window.
    private static let maxInlineKnowledge = 6000

    static func instructions(
        settings: SettingsStore,
        agent: Agent?,
        skills: [Skill],
        knowledge: [KnowledgeFile]
    ) -> String {
        var parts: [String] = []

        // Base persona: agent instructions take priority over the global default.
        parts.append(agent?.instructions ?? settings.globalInstructions)

        // Enabled skills.
        let enabled = skills.filter { $0.isEnabled }
        if !enabled.isEmpty {
            var skillBlock = "You have the following skills. Apply them when relevant:"
            for skill in enabled {
                skillBlock += "\n\n### Skill: \(skill.name)\n\(skill.content)"
            }
            parts.append(skillBlock)
        }

        // Inline knowledge (bounded).
        if settings.injectKnowledge {
            let active = knowledge.filter { $0.isActive }
            if !active.isEmpty {
                var knowledgeBlock = "Use the following knowledge to inform your answers when relevant:"
                var budget = maxInlineKnowledge
                for file in active where budget > 0 {
                    let snippet = String(file.content.prefix(budget))
                    budget -= snippet.count
                    knowledgeBlock += "\n\n### \(file.title)\n\(snippet)"
                }
                parts.append(knowledgeBlock)
            }
        }

        // Language handling.
        if settings.forceDeviceLanguage {
            let locale = Locale.current
            if !Locale.Language(identifier: "en_US").isEquivalent(to: locale.language) {
                parts.append("The person's locale is \(locale.identifier). You MUST respond in their language.")
            }
        }

        return parts.joined(separator: "\n\n")
    }
}

/// Central access point for the on-device model.
@Observable
@MainActor
final class LLMEngine {

    let model = SystemLanguageModel.default

    var availability: SystemLanguageModel.Availability { model.availability }

    var isAvailable: Bool { model.isAvailable }

    /// A human-readable explanation of the current availability state.
    var availabilityDescription: String {
        switch availability {
        case .available:
            return "Apple Intelligence is ready on this device."
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to use MyAI."
        case .unavailable(.modelNotReady):
            return "The model is downloading or preparing. Try again shortly."
        case .unavailable:
            return "The on-device model is currently unavailable."
        }
    }

    /// Languages the on-device model supports, as display names.
    var supportedLanguageNames: [String] {
        let current = Locale.current
        return model.supportedLanguages
            .compactMap { current.localizedString(forLanguageCode: $0.languageCode?.identifier ?? "") }
            .sorted()
            .reduced()
    }

    /// Builds a session configured with the given instructions, knowledge tool, and image tools.
    func makeSession(
        instructions: String,
        knowledge: [KnowledgeEntry],
        useTool: Bool,
        settings: SettingsStore
    ) -> LanguageModelSession {
        var tools: [any Tool] = []
        if useTool && !knowledge.isEmpty {
            tools.append(KnowledgeLookupTool(entries: knowledge))
        }
        // Vision-provided tools that let the model read text and codes inside attached
        // images. These ship on device only — they're absent from the simulator SDK.
        #if !targetEnvironment(simulator)
        if settings.enableOCRTool {
            tools.append(OCRTool())
        }
        if settings.enableBarcodeTool {
            tools.append(BarcodeReaderTool())
        }
        #endif

        // Only route to PCC when the build is entitled — otherwise every request
        // would fail, so fall back to the on-device model.
        if settings.usePrivateCloudCompute && canUsePrivateCloudCompute {
            return LanguageModelSession(
                model: PrivateCloudComputeLanguageModel(),
                tools: tools,
                instructions: instructions
            )
        }
        return LanguageModelSession(tools: tools, instructions: instructions)
    }

    func makeOptions(settings: SettingsStore, temperatureOverride: Double?) -> GenerationOptions {
        let temp = min(max(temperatureOverride ?? settings.temperature, 0), 1)
        let maxTokens = settings.maximumResponseTokens > 0 ? settings.maximumResponseTokens : nil

        let seed: UInt64? = settings.useSeed ? UInt64(max(0, settings.seed)) : nil
        let samplingMode: GenerationOptions.SamplingMode?
        switch settings.samplingStrategy {
        case .automatic:
            samplingMode = nil
        case .greedy:
            samplingMode = .greedy
        case .topK:
            samplingMode = .random(top: max(1, settings.topK), seed: seed)
        case .nucleus:
            samplingMode = .random(probabilityThreshold: min(max(settings.nucleusThreshold, 0), 1), seed: seed)
        }

        return GenerationOptions(samplingMode: samplingMode, temperature: temp, maximumResponseTokens: maxTokens)
    }

    // MARK: - Multimodal prompting

    /// Builds a prompt that combines text with an optional image attachment.
    ///
    /// The model reads the picture directly rather than relying on a text
    /// description of it.
    func makePrompt(text: String, image: UIImage?) -> Prompt {
        guard let image, let cgImage = image.cgImage else {
            return Prompt(text)
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return Prompt {
            text
            Attachment(cgImage, orientation: orientation)
                .label("user-image")
        }
    }

    /// Vision's OCR and barcode tools are only available when running on a device.
    var supportsVisionTools: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    // MARK: - Private Cloud Compute

    /// Whether the app is signed with the managed PCC entitlement.
    ///
    /// `com.apple.developer.private-cloud-compute` has to be requested from Apple
    /// (developer.apple.com/private-cloud-compute). Once it's on the provisioning
    /// profile, add `HAS_PCC_ENTITLEMENT` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS`
    /// to light up the feature.
    var hasPrivateCloudComputeEntitlement: Bool {
        #if HAS_PCC_ENTITLEMENT
        return true
        #else
        return false
        #endif
    }

    /// Whether PCC can actually be used: entitled, and available on this device.
    var canUsePrivateCloudCompute: Bool {
        hasPrivateCloudComputeEntitlement && isPrivateCloudComputeAvailable
    }

    /// Whether the server-side Apple model is reachable on this device.
    var privateCloudComputeDescription: String {
        guard hasPrivateCloudComputeEntitlement else {
            return "Entitlement required — not enabled in this build."
        }
        switch PrivateCloudComputeLanguageModel().availability {
        case .available:
            return "Private Cloud Compute is available."
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.systemNotReady):
            return "Apple Intelligence is still setting up. Try again later."
        case .unavailable:
            return "Private Cloud Compute is currently unavailable."
        }
    }

    var isPrivateCloudComputeAvailable: Bool {
        PrivateCloudComputeLanguageModel().isAvailable
    }

    // MARK: - Hardware & memory (read-only, system-managed)

    /// The maximum context window (in tokens) for a single session.
    ///
    /// Returns nil when the size can't be determined — the model reports 0 when
    /// its assets aren't present, which would otherwise surface as "0 tokens".
    var contextWindowSize: Int? {
        guard isAvailable else { return nil }
        let size = model.contextSize
        return size > 0 ? size : nil
    }

    /// The context window formatted for display, falling back to the documented
    /// on-device window when the live value isn't reportable.
    var contextWindowDescription: String {
        let tokens = contextWindowSize ?? 4096
        let formatted = tokens.formatted(.number.grouping(.automatic))
        return "\(formatted) tokens"
    }

    /// FoundationModels does not expose a compute-unit selector; the OS decides.
    var computeDescription: String {
        "Apple Neural Engine (managed by the system)"
    }
}

private extension Array where Element == String {
    /// De-duplicates while preserving order.
    func reduced() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

private extension CGImagePropertyOrientation {
    /// Maps a UIKit image orientation to the Core Graphics equivalent so the
    /// framework can transform the image before handing it to the model.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
