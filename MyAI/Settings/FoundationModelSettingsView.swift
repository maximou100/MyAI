//
//  FoundationModelSettingsView.swift
//  MyAI
//
//  Settings for Apple's on-device Foundation model, plus curated proposals.
//

import SwiftUI

struct FoundationModelSettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(LLMEngine.self) private var engine

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: engine.isAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(engine.isAvailable ? .green : .orange)
                    Text(engine.availabilityDescription)
                        .font(.callout)
                }
            } header: {
                Text("Status")
            }

            Section {
                ForEach(SettingsStore.proposals) { proposal in
                    Button {
                        settings.apply(proposal)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: proposal.systemImage)
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(proposal.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(proposal.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    // Preserve the title/detail hierarchy inside the button.
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Proposals")
            } footer: {
                Text("Tap a proposal to apply its temperature and instructions.")
            }

            Section("Generation") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.2f", settings.temperature))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.temperature, in: 0...1, step: 0.05)
                    Text("Lower is more precise and predictable; higher is more creative.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Stepper(value: $settings.maximumResponseTokens, in: 0...4000, step: 100) {
                    HStack {
                        Text("Max response tokens")
                        Spacer()
                        Text(settings.maximumResponseTokens == 0 ? "Auto" : "\(settings.maximumResponseTokens)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Picker("Strategy", selection: $settings.samplingStrategy) {
                    ForEach(SettingsStore.SamplingStrategy.allCases) { strategy in
                        Text(strategy.label).tag(strategy)
                    }
                }
                Text(settings.samplingStrategy.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                switch settings.samplingStrategy {
                case .topK:
                    Stepper(value: $settings.topK, in: 1...100) {
                        HStack {
                            Text("K (candidates)")
                            Spacer()
                            Text("\(settings.topK)").foregroundStyle(.secondary)
                        }
                    }
                case .nucleus:
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Probability threshold")
                            Spacer()
                            Text(String(format: "%.2f", settings.nucleusThreshold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.nucleusThreshold, in: 0.1...1.0, step: 0.05)
                    }
                case .automatic, .greedy:
                    EmptyView()
                }

                if settings.samplingStrategy == .topK || settings.samplingStrategy == .nucleus {
                    Toggle("Pin random seed", isOn: $settings.useSeed)
                    if settings.useSeed {
                        Stepper(value: $settings.seed, in: 0...999_999) {
                            HStack {
                                Text("Seed")
                                Spacer()
                                Text("\(settings.seed)").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Sampling")
            } footer: {
                Text("Controls how the next token is chosen. A pinned seed makes output more repeatable (best-effort, not guaranteed).")
            }

            Section {
                LabeledContent("Runs on", value: engine.computeDescription)
                LabeledContent("Context window", value: engine.contextWindowDescription)
            } header: {
                Text("Hardware & Memory")
            } footer: {
                Text("Apple Foundation Models runs on-device and the system chooses the compute units — there's no CPU/GPU/ANE selector, unlike Core ML. Memory is bounded by the fixed context window per conversation.")
            }

            Section("Default Instructions") {
                TextEditor(text: $settings.globalInstructions)
                    .frame(minHeight: 120)
                    .font(.callout)
                Text("Used when no agent is selected. Agents provide their own instructions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Knowledge") {
                Toggle("Inject active knowledge", isOn: $settings.injectKnowledge)
                Toggle("Allow knowledge search tool", isOn: $settings.enableKnowledgeTool)
            }

            Section {
                // Show these as off where the tools can't run, so the switch state
                // doesn't contradict the footer.
                Toggle("Read text in images (OCR)",
                       isOn: engine.supportsVisionTools ? $settings.enableOCRTool : .constant(false))
                    .disabled(!engine.supportsVisionTools)
                Toggle("Scan barcodes & QR codes",
                       isOn: engine.supportsVisionTools ? $settings.enableBarcodeTool : .constant(false))
                    .disabled(!engine.supportsVisionTools)
            } header: {
                Text("Image Understanding")
            } footer: {
                Text(engine.supportsVisionTools
                     ? "The model can look at photos you attach with the + button. These Vision tools let it also extract text and decode codes inside them."
                     : "The model can look at photos you attach with the + button. Vision's OCR and barcode tools are only available on a real device.")
            }

            Section {
                Toggle("Use Private Cloud Compute", isOn: $settings.usePrivateCloudCompute)
                    .disabled(!engine.canUsePrivateCloudCompute)
                LabeledContent("Status", value: engine.privateCloudComputeDescription)
                    .font(.caption)
            } header: {
                Text("Private Cloud Compute")
            } footer: {
                Text(engine.canUsePrivateCloudCompute
                     ? "Runs requests on Apple's server-side model for harder tasks, with the same privacy guarantees."
                     : "Runs harder requests on Apple's server-side model with the same privacy guarantees. This needs the managed Private Cloud Compute entitlement from Apple — request access at developer.apple.com/private-cloud-compute, then set HAS_PCC_ENTITLEMENT in the build settings.")
            }

            Section("Language") {
                Toggle("Prefer device language", isOn: $settings.forceDeviceLanguage)
                if engine.isAvailable && !engine.supportedLanguageNames.isEmpty {
                    NavigationLink {
                        List(engine.supportedLanguageNames, id: \.self) { Text($0) }
                            .navigationTitle("Supported Languages")
                    } label: {
                        LabeledContent("Supported languages", value: "\(engine.supportedLanguageNames.count)")
                    }
                }
            }
        }
        .navigationTitle("Foundation Model")
        .navigationBarTitleDisplayMode(.inline)
    }
}
