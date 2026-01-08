import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

// Note: You must reuse 'VaultManager' and 'JournalService' in the Share Target.
// In Xcode: Select these files -> File Inspector -> Target Membership -> Check 'ObsidianJournalShare'

class ShareViewController: SLComposeServiceViewController {

    private let vaultManager = VaultManager()
    private lazy var journalService = JournalService(vaultManager: vaultManager)

    override func isContentValid() -> Bool {
        return vaultManager.isVaultConfigured && !contentText.isEmpty
    }

    override func didSelectPost() {
        guard let text = contentText else { return }

        let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem

        // TODO: Handle attachments if any (Audio/Images)
        // For now, handling text directly from the compose sheet

        Task {
            do {
                try await journalService.saveEntry(text: text)
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            } catch {
                print("Error saving from share extension: \(error)")
                // In a real app, present an error alert here
                self.extensionContext?.cancelRequest(withError: error)
            }
        }
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
}
