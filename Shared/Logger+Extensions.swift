import Foundation
import os

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "studio.orbitlabs.obsidianjournal"

    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let vault = Logger(subsystem: subsystem, category: "Vault")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let transcription = Logger(subsystem: subsystem, category: "Transcription")
    static let ai = Logger(subsystem: subsystem, category: "AI")
    static let journal = Logger(subsystem: subsystem, category: "Journal")
    static let fileImport = Logger(subsystem: subsystem, category: "FileImport")
}
