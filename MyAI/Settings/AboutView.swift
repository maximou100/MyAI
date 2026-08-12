//
//  AboutView.swift
//  MyAI
//

import SwiftUI

struct AboutView: View {
    @Environment(LLMEngine.self) private var engine

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("MyAI")
                        .font(.largeTitle.weight(.bold))
                    Text(AppInfo.versionString)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section("Details") {
                LabeledContent("Version", value: AppInfo.version)
                LabeledContent("Build", value: AppInfo.build)
                LabeledContent("Author", value: "Maxime Leclercq")
                LabeledContent("Engine", value: "Apple Foundation Models")
            }

            Section("On-Device Model") {
                Text(engine.availabilityDescription)
                    .font(.callout)
                if engine.isAvailable && !engine.supportedLanguageNames.isEmpty {
                    LabeledContent("Languages", value: "\(engine.supportedLanguageNames.count)")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
