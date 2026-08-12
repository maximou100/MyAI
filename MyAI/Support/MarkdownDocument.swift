//
//  MarkdownDocument.swift
//  MyAI
//
//  A FileDocument for exporting Markdown, plus lenient parsers/serializers that
//  convert Agents and Skills to and from .md files.
//

import SwiftUI
import UniformTypeIdentifiers

/// A simple UTF-8 text document used for `.md` import/export.
struct MarkdownDocument: FileDocument {
    static let markdownType = UTType(filenameExtension: "md") ?? .plainText
    static var readableContentTypes: [UTType] { [markdownType, .plainText, .text] }
    static var writableContentTypes: [UTType] { [markdownType, .plainText] }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// Conversion helpers between Markdown files and model objects.
enum MarkdownConverter {

    // MARK: - Agents

    static func markdown(for agent: Agent) -> String {
        """
        # \(agent.name)

        > \(agent.summary)

        Temperature: \(String(format: "%.2f", agent.temperature))

        ## Instructions

        \(agent.instructions)
        """
    }

    struct ParsedAgent {
        var name: String
        var summary: String
        var temperature: Double
        var instructions: String
    }

    static func parseAgent(_ markdown: String, fallbackName: String) -> ParsedAgent {
        let lines = markdown.components(separatedBy: .newlines)
        let name = firstHeading(in: lines) ?? fallbackName
        let summary = firstQuote(in: lines) ?? ""
        let temperature = firstTemperature(in: lines) ?? 0.7
        let instructions = body(after: "## Instructions", in: markdown)
            ?? bodyAfterFrontMatter(markdown)
        return ParsedAgent(
            name: name,
            summary: summary,
            temperature: temperature,
            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Skills

    static func markdown(for skill: Skill) -> String {
        """
        # \(skill.name)

        > \(skill.summary)

        \(skill.content)
        """
    }

    struct ParsedSkill {
        var name: String
        var summary: String
        var content: String
    }

    static func parseSkill(_ markdown: String, fallbackName: String) -> ParsedSkill {
        let lines = markdown.components(separatedBy: .newlines)
        let name = firstHeading(in: lines) ?? fallbackName
        let summary = firstQuote(in: lines) ?? ""
        let content = bodyAfterFrontMatter(markdown).trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedSkill(name: name, summary: summary, content: content)
    }

    // MARK: - Parsing primitives

    private static func firstHeading(in lines: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func firstQuote(in lines: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("> ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func firstTemperature(in lines: [String]) -> Double? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            if trimmed.hasPrefix("temperature:") {
                let value = trimmed.replacingOccurrences(of: "temperature:", with: "")
                return Double(value.trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    /// Returns everything after a given heading line.
    private static func body(after heading: String, in markdown: String) -> String? {
        guard let range = markdown.range(of: heading) else { return nil }
        return String(markdown[range.upperBound...])
    }

    /// Returns the body after dropping the leading title/summary/metadata lines.
    private static func bodyAfterFrontMatter(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var result: [String] = []
        var passedFrontMatter = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !passedFrontMatter {
                if trimmed.isEmpty { continue }
                if trimmed.hasPrefix("# ") { continue }
                if trimmed.hasPrefix("> ") { continue }
                if trimmed.lowercased().hasPrefix("temperature:") { continue }
                passedFrontMatter = true
            }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }
}
