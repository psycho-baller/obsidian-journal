import Foundation
import os

public struct AIResponse: Codable {
    public let summary: String
    public let insights: [String]
    public let actionItems: [String]
    public let tags: [String]

    enum CodingKeys: String, CodingKey {
        case summary
        case insights
        case actionItems = "action_items"
        case tags
    }
}

class JournalService: ObservableObject {
    private let vaultManager: VaultManager

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    // MARK: - Core Logic

    func saveEntry(text: String, date: Date = Date()) async throws {
        Logger.journal.info("Starting saveEntry process...")
        try vaultManager.performInVault { vaultURL in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fileName = dateFormatter.string(from: date) + ".md"

            let dailyNoteURL = vaultURL.appendingPathComponent(fileName)
            Logger.journal.debug("Target file: \(dailyNoteURL.path)")

            // formatting
            let timestamp = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
            let newContent = """

            ## \(timestamp) Flash Journal
            > \(text)

            """

            if FileManager.default.fileExists(atPath: dailyNoteURL.path) {
                // Append
                Logger.journal.info("Appending to existing note.")
                let fileHandle = try FileHandle(forWritingTo: dailyNoteURL)
                fileHandle.seekToEndOfFile()
                if let data = newContent.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // Create New
                Logger.journal.info("Creating new daily note.")
                let initialContent = """
                # Daily Note: \(dateFormatter.string(from: date))

                \(newContent)
                """
                try initialContent.write(to: dailyNoteURL, atomically: true, encoding: .utf8)
            }
            Logger.journal.notice("Entry saved successfully.")
        }
    }

    // MARK: - AI Integration
    func saveAIEntry(originalText: String, aiResponse: AIResponse, date: Date = Date()) async throws {
        Logger.journal.info("Starting saveAIEntry process...")
        try vaultManager.performInVault { vaultURL in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fileName = dateFormatter.string(from: date) + ".md"
            let dailyNoteURL = vaultURL.appendingPathComponent(fileName)
            Logger.journal.debug("Target AI file: \(dailyNoteURL.path)")

            let timestamp = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)

            // Format MD
            var mdContent = """

            ## \(timestamp) Voice Journal
            > \(originalText)

            ### AI Insights
            **Summary**: \(aiResponse.summary)

            **Key Realizations**:
            \(aiResponse.insights.map { "- " + $0 }.joined(separator: "\n"))

            **Action Items**:
            \(aiResponse.actionItems.map { "- [ ] " + $0 }.joined(separator: "\n"))

            **Tags**: \(aiResponse.tags.map { "#" + $0 }.joined(separator: " "))

            """

            if FileManager.default.fileExists(atPath: dailyNoteURL.path) {
                Logger.journal.info("Appending AI entry to existing note.")
                let fileHandle = try FileHandle(forWritingTo: dailyNoteURL)
                fileHandle.seekToEndOfFile()
                if let data = mdContent.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                Logger.journal.info("Creating new daily note for AI entry.")
                let initialContent = """
                # Daily Note: \(dateFormatter.string(from: date))
                \(mdContent)
                """
                try initialContent.write(to: dailyNoteURL, atomically: true, encoding: .utf8)
            }
            Logger.journal.notice("AI Entry saved successfully.")
        }
    }
}
