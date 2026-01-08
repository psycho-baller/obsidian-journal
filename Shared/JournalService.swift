import Foundation
import os

class JournalService: ObservableObject {
    private let vaultManager: VaultManager

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    // MARK: - Template Population Support

    /// Reads the existing daily note for a given date, or returns nil if it doesn't exist.
    func readDailyNote(for date: Date) throws -> String? {
        var result: String? = nil
        try vaultManager.performInVault { vaultURL in
            let fileName = Self.dateFormatter.string(from: date) + ".md"
            let noteURL = vaultURL.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: noteURL.path) {
                result = try String(contentsOf: noteURL, encoding: .utf8)
                Logger.journal.debug("Read existing daily note: \(fileName)")
            }
        }
        return result
    }

    /// Returns a default template for new daily notes.
    func getDefaultTemplate(for date: Date) -> String {
        let dateString = Self.dateFormatter.string(from: date)
        return """
        # Daily Note: \(dateString)

        ## Metrics
        - Mood:
        - Energy:
        - Sleep Hours:

        ## Morning Intentions

        ## Things I Learned

        ## Gratitude

        ## Tasks Completed

        ## Reflections

        """
    }

    /// Applies AI-generated template updates to a note and saves it.
    /// This method should be called AFTER getting the updates from LLMService.
    func applyTemplateUpdates(_ updates: [TemplateUpdate], to existingNote: String, for date: Date) throws {
        Logger.journal.info("Applying \(updates.count) template updates...")

        var result = existingNote

        for update in updates {
            guard let value = update.value, !value.isEmpty else { continue }

            switch update.updateType {
            case .metric:
                result = applyMetricUpdate(to: result, field: update.field, value: value)

            case .append:
                result = applyAppendUpdate(to: result, field: update.field, value: value)

            case .replace:
                result = applyReplaceUpdate(to: result, field: update.field, value: value)
            }
        }

        try saveDailyNote(content: result, for: date)
        Logger.journal.notice("Template updates applied and saved.")
    }

    private func applyMetricUpdate(to note: String, field: String, value: String) -> String {
        var lines = note.components(separatedBy: "\n")
        let normalizedField = field.trimmingCharacters(in: CharacterSet(charactersIn: "#- "))

        for (index, line) in lines.enumerated() {
            if line.contains("\(normalizedField):") {
                if let colonRange = line.range(of: ":") {
                    let beforeColon = String(line[..<colonRange.upperBound])
                    let afterColon = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

                    if afterColon.isEmpty {
                        lines[index] = beforeColon + " " + value
                        Logger.journal.debug("Updated metric '\(field)' to '\(value)'")
                    }
                }
                break
            }
        }

        return lines.joined(separator: "\n")
    }

    private func applyAppendUpdate(to note: String, field: String, value: String) -> String {
        var lines = note.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine == field || trimmedLine.hasPrefix(field) {
                var insertIndex = index + 1

                while insertIndex < lines.count {
                    let nextLine = lines[insertIndex].trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("#") {
                        break
                    }
                    insertIndex += 1
                }

                let contentToInsert = value.hasPrefix("-") ? value : "- " + value
                lines.insert(contentToInsert, at: insertIndex)

                Logger.journal.debug("Appended to section '\(field)'")
                break
            }
        }

        return lines.joined(separator: "\n")
    }

    private func applyReplaceUpdate(to note: String, field: String, value: String) -> String {
        Logger.journal.debug("Replace update for '\(field)' - using append behavior for safety")
        return applyAppendUpdate(to: note, field: field, value: value)
    }

    private func saveDailyNote(content: String, for date: Date) throws {
        try vaultManager.performInVault { vaultURL in
            let fileName = Self.dateFormatter.string(from: date) + ".md"
            let noteURL = vaultURL.appendingPathComponent(fileName)
            try content.write(to: noteURL, atomically: true, encoding: .utf8)
            Logger.journal.info("Saved daily note: \(fileName)")
        }
    }

    // MARK: - Template-Based Note Creation

    /// Creates a new daily note using an inferred template
    /// - Parameters:
    ///   - date: The date for the new note
    ///   - template: The InferredTemplate to use (from VaultManager.inferredTemplate)
    /// - Throws: VaultError if vault is not configured
    func createDailyNote(for date: Date, using template: InferredTemplate) throws {
        let renderedContent = TemplateEngine.render(template, for: date)
        try saveDailyNote(content: renderedContent, for: date)
        Logger.journal.notice("Created new daily note from inferred template for \(Self.dateFormatter.string(from: date))")
    }

    /// Gets or creates the daily note for a given date
    /// - Parameters:
    ///   - date: The date for the note
    ///   - template: Optional inferred template. If nil and note doesn't exist, uses default template.
    /// - Returns: The content of the daily note
    func getOrCreateDailyNote(for date: Date, template: InferredTemplate?) throws -> String {
        // Check if note already exists
        if let existingNote = try readDailyNote(for: date) {
            return existingNote
        }

        // Note doesn't exist - create it
        let content: String
        if let inferredTemplate = template {
            content = TemplateEngine.render(inferredTemplate, for: date)
            Logger.journal.info("Creating new note from inferred template")
        } else {
            content = getDefaultTemplate(for: date)
            Logger.journal.info("Creating new note from default template")
        }

        try saveDailyNote(content: content, for: date)
        return content
    }

    // MARK: - Legacy Methods (Backward Compatibility)

    func saveEntry(text: String, date: Date = Date()) async throws {
        Logger.journal.info("Starting saveEntry process...")
        try vaultManager.performInVault { vaultURL in
            let fileName = Self.dateFormatter.string(from: date) + ".md"
            let dailyNoteURL = vaultURL.appendingPathComponent(fileName)

            let timestamp = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
            let newContent = """

            ## \(timestamp) Flash Journal
            > \(text)

            """

            if FileManager.default.fileExists(atPath: dailyNoteURL.path) {
                let fileHandle = try FileHandle(forWritingTo: dailyNoteURL)
                fileHandle.seekToEndOfFile()
                if let data = newContent.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                let initialContent = """
                # Daily Note: \(Self.dateFormatter.string(from: date))

                \(newContent)
                """
                try initialContent.write(to: dailyNoteURL, atomically: true, encoding: .utf8)
            }
            Logger.journal.notice("Entry saved successfully.")
        }
    }

    func saveAIEntry(originalText: String, aiResponse: AIResponse, date: Date = Date()) async throws {
        Logger.journal.info("Starting saveAIEntry process...")
        try vaultManager.performInVault { vaultURL in
            let fileName = Self.dateFormatter.string(from: date) + ".md"
            let dailyNoteURL = vaultURL.appendingPathComponent(fileName)

            let timestamp = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)

            let mdContent = """

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
                let fileHandle = try FileHandle(forWritingTo: dailyNoteURL)
                fileHandle.seekToEndOfFile()
                if let data = mdContent.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                let initialContent = """
                # Daily Note: \(Self.dateFormatter.string(from: date))
                \(mdContent)
                """
                try initialContent.write(to: dailyNoteURL, atomically: true, encoding: .utf8)
            }
            Logger.journal.notice("AI Entry saved successfully.")
        }
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
