import SwiftUI

@main
struct IgniteApp: App {
    @StateObject private var draftManager = DraftManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(draftManager)
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .onAppear {
                    // Check for shared content on app launch (cold start) from Defaults as backup
                    checkForSharedContent()
                }
        }
    }

    private func handleOpenURL(_ url: URL) {
        // 1. Check for content in URL query (Primary Method)
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let content = queryItems.first(where: { $0.name == "content" })?.value {

            appendContent(content)
            return
        }

        guard url.scheme == "ignite" && url.host == "open-shared" else { return }

        // 2. Fallback to App Group Defaults
        checkForSharedContent()
    }

    private func checkForSharedContent(retryCount: Int = 0) {
        guard let defaults = UserDefaults(suiteName: "group.studio.orbitlabs.ignite") else { return }

        guard let sharedText = defaults.string(forKey: "shared_content") else {
            // Retry a few times just in case of race condition
            if retryCount < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.checkForSharedContent(retryCount: retryCount + 1)
                }
            }
            return
        }

        // Clear it immediately
        defaults.removeObject(forKey: "shared_content")
        defaults.synchronize()

        appendContent(sharedText)
    }

    private func appendContent(_ text: String) {
        DispatchQueue.main.async {
            if let current = self.draftManager.currentDraft {
                let newContent = current.content.isEmpty ? text : current.content + "\n\n" + text
                self.draftManager.updateCurrentDraft(content: newContent)
            } else {
                self.draftManager.createNewDraft()
                self.draftManager.updateCurrentDraft(content: text)
            }
        }
    }
}
