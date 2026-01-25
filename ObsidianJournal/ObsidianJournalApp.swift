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
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "ignite" && url.host == "open-shared" else { return }

        // Read from shared defaults
        if let defaults = UserDefaults(suiteName: "group.studio.orbitlabs.ignite") {
            if let sharedText = defaults.string(forKey: "shared_content") {
                // Clear it immediately so we don't process it again
                defaults.removeObject(forKey: "shared_content")
                defaults.synchronize()

                print("Received shared text: \(sharedText)")

                // Append to current draft
                DispatchQueue.main.async {
                    if let current = draftManager.currentDraft {
                        let newContent = current.content.isEmpty ? sharedText : current.content + "\n\n" + sharedText
                        draftManager.updateCurrentDraft(content: newContent)
                    } else {
                         // Should typically have a current draft from init, but just in case
                         draftManager.createNewDraft()
                         if let current = draftManager.currentDraft {
                             draftManager.updateCurrentDraft(content: sharedText)
                         }
                    }
                }
            }
        }
    }
}
