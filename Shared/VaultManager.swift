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

    init() {
        restoreAccess()
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
            // iOS: security-scoped bookmark options are unavailable; create a standard bookmark
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

        #if os(macOS)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        #endif

        return try block(url)
    }
}

enum VaultError: Error {
    case notConfigured
    case accessDenied
}
