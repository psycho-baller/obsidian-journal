import Foundation
import SwiftUI
import os

class VaultManager: ObservableObject {
    // TODO: explicit suiteName is required for Share Extension to see this.
    // User must replace "group.com.example.obsidianjournal" with their actual App Group ID.
    private let defaults = UserDefaults(suiteName: "group.studio.orbitlabs.obsidianjournal")

    @Published var vaultURL: URL?
    @Published var isVaultConfigured: Bool = false
    @Published var error: String?
    @Published var inferredTemplate: InferredTemplate?

    private static let templateKey = "inferredTemplate"

    init() {
        restoreAccess()
        restoreTemplate()
    }

    func restoreAccess() {
        guard let bookmark = defaults?.data(forKey: "vaultBookmark") else {
            Logger.vault.debug("No vault bookmark found in defaults.")
            return
        }

        var isStale = false
        do {
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: bookmark,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            #else
            let url = try URL(resolvingBookmarkData: bookmark,
                              options: [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            #endif

            if isStale {
                Logger.vault.warning("Bookmark is stale")
            }

            #if os(macOS)
            if url.startAccessingSecurityScopedResource() {
                self.vaultURL = url
                self.isVaultConfigured = true
                Logger.vault.info("Successfully restored access to: \(url.path)")
            } else {
                self.error = "Could not access the folder. Please select it again."
                self.defaults?.removeObject(forKey: "vaultBookmark")
                self.isVaultConfigured = false
                Logger.vault.error("Failed to access security scoped resource.")
            }
            #else
            // iOS: security-scoped bookmarks options are unavailable; use URL directly
            self.vaultURL = url
            self.isVaultConfigured = true
            Logger.vault.info("Successfully restored access to: \(url.path)")
            #endif
        } catch {
            Logger.vault.error("Error parsing bookmark: \(error.localizedDescription)")
            self.error = "Error restoring access: \(error.localizedDescription)"
            self.defaults?.removeObject(forKey: "vaultBookmark")
            self.isVaultConfigured = false
        }
    }

    func setVaultFolder(_ url: URL) {
        do {
            #if os(macOS)
            // Need to start accessing to create valid security-scoped bookmark on macOS
            guard url.startAccessingSecurityScopedResource() else {
                self.error = "Failed to access selected folder"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let bookmark = try url.bookmarkData(options: .securityScopeAllowOnlyReadAccess,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            #else
            // iOS
            guard url.startAccessingSecurityScopedResource() else {
                 self.error = "Failed to access selected folder"
                 return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let bookmark = try url.bookmarkData(options: [],
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            #endif

            self.defaults?.set(bookmark, forKey: "vaultBookmark")

            // Re-trigger restore to set state correctly
            restoreAccess()

        } catch {
            self.error = "Failed to save folder permission: \(error.localizedDescription)"
        }
    }

    func reset() {
        defaults?.removeObject(forKey: "vaultBookmark")
        self.vaultURL = nil
        self.isVaultConfigured = false
        self.error = nil
    }

    // Usage: `try? vaultManager.performInVault { vaultUrl in ... }`
    func performInVault<T>(_ block: (URL) throws -> T) throws -> T {
        guard let url = vaultURL else {
            throw VaultError.notConfigured
        }

        // Create access scope for both iOS and macOS
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try block(url)
    }

    // MARK: - Template Inference Support

    /// Fetches the most recent daily notes from the vault for template inference
    /// - Parameter count: Maximum number of notes to fetch (default 5)
    /// - Returns: Array of DailyNoteSample, sorted newest first
    func fetchRecentDailyNotes(count: Int = 5) throws -> [DailyNoteSample] {
        return try performInVault { vaultURL in
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: vaultURL, includingPropertiesForKeys: [.contentModificationDateKey])

            // Filter for markdown files that look like daily notes (YYYY-MM-DD.md pattern)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            var dailyNotes: [(date: Date, url: URL)] = []

            for fileURL in contents {
                guard fileURL.pathExtension == "md" else { continue }

                let filename = fileURL.deletingPathExtension().lastPathComponent
                if let date = dateFormatter.date(from: filename) {
                    dailyNotes.append((date: date, url: fileURL))
                }
            }

            // Sort by date descending (newest first) and take the requested count
            let sortedNotes = dailyNotes.sorted { $0.date > $1.date }.prefix(count)

            var samples: [DailyNoteSample] = []
            for note in sortedNotes {
                if let content = try? String(contentsOf: note.url, encoding: .utf8) {
                    samples.append(DailyNoteSample(date: note.date, content: content))
                }
            }

            Logger.vault.info("Fetched \(samples.count) daily notes for template inference")
            return samples
        }
    }

    /// Saves an inferred template to UserDefaults
    /// - Parameter template: The InferredTemplate to cache
    func saveTemplate(_ template: InferredTemplate) {
        do {
            let data = try JSONEncoder().encode(template)
            defaults?.set(data, forKey: Self.templateKey)
            self.inferredTemplate = template
            Logger.vault.info("Saved inferred template with confidence \(template.confidence)")
        } catch {
            Logger.vault.error("Failed to save template: \(error.localizedDescription)")
        }
    }

    /// Restores the cached template from UserDefaults
    private func restoreTemplate() {
        guard let data = defaults?.data(forKey: Self.templateKey) else {
            Logger.vault.debug("No cached template found")
            return
        }

        do {
            let template = try JSONDecoder().decode(InferredTemplate.self, from: data)
            self.inferredTemplate = template
            Logger.vault.info("Restored cached template with confidence \(template.confidence)")
        } catch {
            Logger.vault.error("Failed to restore template: \(error.localizedDescription)")
            defaults?.removeObject(forKey: Self.templateKey)
        }
    }

    /// Clears the cached template
    func clearTemplate() {
        defaults?.removeObject(forKey: Self.templateKey)
        self.inferredTemplate = nil
        Logger.vault.info("Cleared cached template")
    }
}

enum VaultError: Error {
    case notConfigured
    case accessDenied
}
