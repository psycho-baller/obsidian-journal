import Foundation
import SwiftUI

class VaultManager: ObservableObject {
    // TODO: explicit suiteName is required for Share Extension to see this.
    // User must replace "group.com.example.obsidianjournal" with their actual App Group ID.
    private let defaults = UserDefaults(suiteName: "group.com.example.obsidianjournal")

    @Published var vaultURL: URL?
    @Published var isVaultConfigured: Bool = false
    @Published var error: String?

    init() {
        restoreAccess()
    }

    func restoreAccess() {
        guard let bookmark = defaults?.data(forKey: "vaultBookmark") else { return }

        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmark,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale)

            if isStale {
                // Determine what to do if stale (request again), for now just try to use it
                print("Bookmark is stale")
            }

            if url.startAccessingSecurityScopedResource() {
                self.vaultURL = url
                self.isVaultConfigured = true
                print("Successfully restored access to: \(url.path)")
            } else {
                self.error = "Could not access the folder. Please select it again."
                self.defaults?.removeObject(forKey: "vaultBookmark")
                self.isVaultConfigured = false
            }
        } catch {
            print("Error parsing bookmark: \(error)")
            self.error = "Error restoring access: \(error.localizedDescription)"
            self.defaults?.removeObject(forKey: "vaultBookmark")
            self.isVaultConfigured = false
        }
    }

    func setVaultFolder(_ url: URL) {
        do {
            // Need to start accessing to create valid bookmark
            guard url.startAccessingSecurityScopedResource() else {
                self.error = "Failed to access selected folder"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let bookmark = try url.bookmarkData(options: .securityScopeAllowOnlyReadAccess,
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil)

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

        // Ensure we are accessing
        // Note: For long running apps, we might keep it open, but safe pattern is to ensure it is open
        // `startAccessingSecurityScopedResource` calls are reference counted according to Apple docs,
        // so calling it again is safe as long as we balance with stop.
        // However, we already called it in restoreAccess() and kept it open.
        // Apple recommends stopping when not in use, but for a "companion" app constantly writing, keeping it open while app is active is common.
        // To be safe against suspension, we can re-assert:

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try block(url)
    }
}

enum VaultError: Error {
    case notConfigured
    case accessDenied
}
