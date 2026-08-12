//
//  SampleData.swift
//  MyAI
//
//  Seeds a few example knowledge files, agents, and skills on first launch so
//  the features are immediately explorable.
//

import Foundation
import SwiftData

enum SampleData {

    private static let seededKey = "sampleData.seeded.v1"

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)

        for file in knowledge { context.insert(file) }
        for agent in agents { context.insert(agent) }
        for skill in skills { context.insert(skill) }

        try? context.save()
    }

    // MARK: - Seed content

    private static var knowledge: [KnowledgeFile] {
        [
            KnowledgeFile(
                title: "About MyAI",
                content: """
                MyAI is an on-device assistant built with Apple's Foundation Models framework. \
                It runs entirely on the user's device using Apple Intelligence, so conversations \
                stay private. The app supports chat, knowledge files, configurable agents, and skills.
                """
            ),
            KnowledgeFile(
                title: "Company Facts (Example)",
                content: """
                Acme Corp was founded in 2015 and is headquartered in Lyon, France. \
                Its flagship product is the Acme Widget, released in 2018. \
                Support hours are Monday to Friday, 9am–6pm CET. The return policy allows \
                returns within 30 days of purchase with a receipt.
                """,
                isActive: false
            )
        ]
    }

    private static var agents: [Agent] {
        [
            Agent(
                name: "Code Helper",
                summary: "A concise programming assistant.",
                instructions: """
                You are a senior software engineer. Give correct, concise answers with short \
                code examples when useful. Prefer Swift and modern APIs. Explain trade-offs briefly.
                """,
                temperature: 0.3
            ),
            Agent(
                name: "Brainstorm Buddy",
                summary: "Playful ideation partner.",
                instructions: """
                You are an energetic brainstorming partner. Offer many diverse ideas, build on the \
                user's thoughts, and keep momentum. Use short, punchy bullet points.
                """,
                temperature: 0.9
            )
        ]
    }

    private static var skills: [Skill] {
        [
            Skill(
                name: "Cite Sources",
                summary: "Reference the knowledge used.",
                content: """
                When you use information from the knowledge base to answer, briefly mention which \
                knowledge entry it came from so the user can verify it.
                """
            ),
            Skill(
                name: "Step-by-Step",
                summary: "Explain reasoning in clear steps.",
                content: """
                For how-to or problem-solving questions, present the answer as clear, numbered steps. \
                Keep each step short and actionable.
                """
            )
        ]
    }
}
