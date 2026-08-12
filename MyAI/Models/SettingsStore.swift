//
//  SettingsStore.swift
//  MyAI
//
//  Observable, UserDefaults-backed store for the Apple Foundation model settings
//  that are shared between the Chat and Settings tabs.
//

import Foundation
import Observation

@Observable
final class SettingsStore {

    /// How the model picks the next token from its probability distribution.
    enum SamplingStrategy: String, CaseIterable, Identifiable {
        case automatic      // Let the system choose (sampling = nil).
        case greedy         // Always the most likely token — fully deterministic.
        case topK           // Sample from the K most likely tokens.
        case nucleus        // Top-p: sample from the smallest set exceeding a probability threshold.

        var id: String { rawValue }

        var label: String {
            switch self {
            case .automatic: return "Automatic"
            case .greedy: return "Greedy"
            case .topK: return "Top-K"
            case .nucleus: return "Nucleus (Top-P)"
            }
        }

        var detail: String {
            switch self {
            case .automatic: return "The system picks a sensible strategy for you."
            case .greedy: return "Always chooses the most likely token. Deterministic, but less varied."
            case .topK: return "Samples from the K most probable tokens."
            case .nucleus: return "Samples from the smallest pool whose probability exceeds the threshold."
            }
        }
    }

    /// A named preset that proposes a good starting configuration.
    struct Proposal: Identifiable {
        let id = UUID()
        let name: String
        let systemImage: String
        let detail: String
        let temperature: Double
        let instructions: String
    }

    private let defaults = UserDefaults.standard

    // MARK: - Stored settings

    /// Creativity of the model, 0 (precise) ... 1 (creative).
    var temperature: Double {
        didSet { persist(temperature, forKey: Keys.temperature) }
    }

    /// Upper bound on response length. 0 means "no explicit limit".
    var maximumResponseTokens: Int {
        didSet { persist(maximumResponseTokens, forKey: Keys.maxTokens) }
    }

    /// The default system instructions used when no agent is selected.
    var globalInstructions: String {
        didSet { persist(globalInstructions, forKey: Keys.instructions) }
    }

    /// The currently selected agent id, or empty for the default assistant.
    var selectedAgentID: String {
        didSet { persist(selectedAgentID, forKey: Keys.selectedAgent) }
    }

    /// Whether active knowledge files are injected into the model's instructions.
    var injectKnowledge: Bool {
        didSet { persist(injectKnowledge, forKey: Keys.injectKnowledge) }
    }

    /// Whether the model is given a tool to search the knowledge base on demand.
    var enableKnowledgeTool: Bool {
        didSet { persist(enableKnowledgeTool, forKey: Keys.knowledgeTool) }
    }

    /// Whether to force the model to answer in the device language.
    var forceDeviceLanguage: Bool {
        didSet { persist(forceDeviceLanguage, forKey: Keys.forceLanguage) }
    }

    /// The token-sampling strategy.
    var samplingStrategy: SamplingStrategy {
        didSet { persist(samplingStrategy.rawValue, forKey: Keys.sampling) }
    }

    /// Number of candidate tokens for Top-K sampling.
    var topK: Int {
        didSet { persist(topK, forKey: Keys.topK) }
    }

    /// Cumulative probability threshold (0...1) for nucleus sampling.
    var nucleusThreshold: Double {
        didSet { persist(nucleusThreshold, forKey: Keys.nucleus) }
    }

    /// Whether to pin a random seed for more repeatable output (best-effort).
    var useSeed: Bool {
        didSet { persist(useSeed, forKey: Keys.useSeed) }
    }

    /// The random seed used when `useSeed` is on.
    var seed: Int {
        didSet { persist(seed, forKey: Keys.seed) }
    }

    /// Gives the model Vision's OCR tool so it can read text inside attached images.
    var enableOCRTool: Bool {
        didSet { persist(enableOCRTool, forKey: Keys.ocrTool) }
    }

    /// Gives the model Vision's barcode tool so it can decode codes in attached images.
    var enableBarcodeTool: Bool {
        didSet { persist(enableBarcodeTool, forKey: Keys.barcodeTool) }
    }

    /// Routes requests to Apple's server-side model instead of the on-device one.
    var usePrivateCloudCompute: Bool {
        didSet { persist(usePrivateCloudCompute, forKey: Keys.pcc) }
    }

    // MARK: - Init

    /// Suppresses write-back while values are being refreshed from iCloud.
    private var isApplyingRemoteChange = false

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            Keys.temperature: 0.7,
            Keys.maxTokens: 0,
            Keys.instructions: SettingsStore.defaultInstructions,
            Keys.selectedAgent: "",
            Keys.injectKnowledge: true,
            Keys.knowledgeTool: true,
            Keys.forceLanguage: false,
            Keys.sampling: SamplingStrategy.automatic.rawValue,
            Keys.topK: 50,
            Keys.nucleus: 0.9,
            Keys.useSeed: false,
            Keys.seed: 42,
            Keys.ocrTool: true,
            Keys.barcodeTool: false,
            Keys.pcc: false
        ])

        // Pull any newer values from iCloud before seeding local state, so a
        // device that's been offline adopts settings changed elsewhere.
        CloudSettingsStore.shared.register(keys: Keys.all)

        self.temperature = d.double(forKey: Keys.temperature)
        self.maximumResponseTokens = d.integer(forKey: Keys.maxTokens)
        self.globalInstructions = d.string(forKey: Keys.instructions) ?? SettingsStore.defaultInstructions
        self.selectedAgentID = d.string(forKey: Keys.selectedAgent) ?? ""
        self.injectKnowledge = d.bool(forKey: Keys.injectKnowledge)
        self.enableKnowledgeTool = d.bool(forKey: Keys.knowledgeTool)
        self.forceDeviceLanguage = d.bool(forKey: Keys.forceLanguage)
        self.samplingStrategy = SamplingStrategy(rawValue: d.string(forKey: Keys.sampling) ?? "") ?? .automatic
        self.topK = d.integer(forKey: Keys.topK)
        self.nucleusThreshold = d.double(forKey: Keys.nucleus)
        self.useSeed = d.bool(forKey: Keys.useSeed)
        self.seed = d.integer(forKey: Keys.seed)
        self.enableOCRTool = d.bool(forKey: Keys.ocrTool)
        self.enableBarcodeTool = d.bool(forKey: Keys.barcodeTool)
        self.usePrivateCloudCompute = d.bool(forKey: Keys.pcc)

        NotificationCenter.default.addObserver(
            forName: CloudSettingsStore.didChangeExternally,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromDefaults()
        }
    }

    // MARK: - Persistence

    /// Writes a value to local defaults and mirrors it to iCloud.
    ///
    /// Skipped while applying an incoming iCloud change, otherwise refreshing
    /// local state would echo the same values straight back to the cloud.
    private func persist(_ value: Any?, forKey key: String) {
        guard !isApplyingRemoteChange else { return }
        CloudSettingsStore.shared.set(value, forKey: key)
    }

    /// Re-reads every setting after iCloud delivers changes from another device.
    private func reloadFromDefaults() {
        let d = UserDefaults.standard
        isApplyingRemoteChange = true
        defer { isApplyingRemoteChange = false }

        temperature = d.double(forKey: Keys.temperature)
        maximumResponseTokens = d.integer(forKey: Keys.maxTokens)
        globalInstructions = d.string(forKey: Keys.instructions) ?? SettingsStore.defaultInstructions
        selectedAgentID = d.string(forKey: Keys.selectedAgent) ?? ""
        injectKnowledge = d.bool(forKey: Keys.injectKnowledge)
        enableKnowledgeTool = d.bool(forKey: Keys.knowledgeTool)
        forceDeviceLanguage = d.bool(forKey: Keys.forceLanguage)
        samplingStrategy = SamplingStrategy(rawValue: d.string(forKey: Keys.sampling) ?? "") ?? .automatic
        topK = d.integer(forKey: Keys.topK)
        nucleusThreshold = d.double(forKey: Keys.nucleus)
        useSeed = d.bool(forKey: Keys.useSeed)
        seed = d.integer(forKey: Keys.seed)
        enableOCRTool = d.bool(forKey: Keys.ocrTool)
        enableBarcodeTool = d.bool(forKey: Keys.barcodeTool)
        usePrivateCloudCompute = d.bool(forKey: Keys.pcc)
    }

    /// Whether settings are currently mirroring to iCloud.
    var isCloudSyncAvailable: Bool { CloudSettingsStore.shared.isAvailable }

    // MARK: - Proposals

    /// Curated presets shown in Settings to help the user get started quickly.
    static let proposals: [Proposal] = [
        Proposal(
            name: "Balanced Assistant",
            systemImage: "scalemass",
            detail: "Helpful, clear, and grounded. A great everyday default.",
            temperature: 0.7,
            instructions: defaultInstructions
        ),
        Proposal(
            name: "Precise Analyst",
            systemImage: "target",
            detail: "Low creativity for factual, concise, to-the-point answers.",
            temperature: 0.2,
            instructions: """
            You are a precise, factual assistant. Answer concisely and directly. \
            Prefer bullet points and short paragraphs. If you are unsure, say so \
            rather than guessing.
            """
        ),
        Proposal(
            name: "Creative Writer",
            systemImage: "sparkles",
            detail: "Higher creativity for brainstorming and storytelling.",
            temperature: 1.0,
            instructions: """
            You are an imaginative writing partner. Offer vivid, original ideas and \
            playful language. Take creative risks while staying coherent and on-topic.
            """
        )
    ]

    func apply(_ proposal: Proposal) {
        temperature = proposal.temperature
        globalInstructions = proposal.instructions
    }

    static let defaultInstructions = """
    You are MyAI, a friendly and helpful on-device assistant. Be clear, accurate, \
    and concise. Use Markdown for structure when it helps readability.
    """

    private enum Keys {
        static let temperature = "settings.temperature"
        static let maxTokens = "settings.maxResponseTokens"
        static let instructions = "settings.globalInstructions"
        static let selectedAgent = "settings.selectedAgentID"
        static let injectKnowledge = "settings.injectKnowledge"
        static let knowledgeTool = "settings.enableKnowledgeTool"
        static let forceLanguage = "settings.forceDeviceLanguage"
        static let sampling = "settings.samplingStrategy"
        static let topK = "settings.topK"
        static let nucleus = "settings.nucleusThreshold"
        static let useSeed = "settings.useSeed"
        static let seed = "settings.seed"
        static let ocrTool = "settings.enableOCRTool"
        static let barcodeTool = "settings.enableBarcodeTool"
        static let pcc = "settings.usePrivateCloudCompute"

        /// Every key mirrored to iCloud.
        static let all: [String] = [
            temperature, maxTokens, instructions, selectedAgent,
            injectKnowledge, knowledgeTool, forceLanguage,
            sampling, topK, nucleus, useSeed, seed,
            ocrTool, barcodeTool, pcc
        ]
    }
}
