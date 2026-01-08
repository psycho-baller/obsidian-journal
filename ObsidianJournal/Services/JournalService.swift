import Foundation

class JournalService: ObservableObject {
    private let vaultManager: VaultManager

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    // MARK: - Core Logic

    func saveEntry(text: String, date: Date = Date()) async throws {
        try vaultManager.performInVault { vaultURL in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fileName = dateFormatter.string(from: date) + ".md"

            let dailyNoteURL = vaultURL.appendingPathComponent(fileName)

            // formatting
            let timestamp = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
            let newContent = """

            ## \(timestamp) Flash Journal
            \(text)

            """

            if FileManager.default.fileExists(atPath: dailyNoteURL.path) {
                // Append
                let fileHandle = try FileHandle(forWritingTo: dailyNoteURL)
                fileHandle.seekToEndOfFile()
                if let data = newContent.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // Create New
                let initialContent = """
                # Daily Note: \(dateFormatter.string(from: date))

                \(newContent)
                """
                try initialContent.write(to: dailyNoteURL, atomically: true, encoding: .utf8)
            }
        }
    }
}
