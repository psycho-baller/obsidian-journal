import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers
import AVFoundation

// Note: Ensure 'VaultManager', 'JournalService', 'TranscriberService', 'LLMService', 'KeychainManager'
// and relevant models are added to the 'ObsidianJournalShare' target membership.

class ShareViewController: SLComposeServiceViewController {

    private let vaultManager = VaultManager()
    private lazy var journalService = JournalService(vaultManager: vaultManager)

    // Lazy load services to avoid overhead until needed
    private lazy var transcriberService = TranscriberService()
    private lazy var llmService = LLMService()

    override func isContentValid() -> Bool {
        // We validate that we have either text or an attachment we can handle
        return vaultManager.isVaultConfigured && (!contentText.isEmpty || !extensionContext!.inputItems.isEmpty)
    }

    override func didSelectPost() {
        // The user hit "Post". We need to process the content.
        // This might take some time, so we should consider UI feedback, but for a Share Extension
        // we can just run the task. The UI will disappear immediately if we call completeRequest,
        // which might kill our process.
        // Strategy: Keep the view alive (don't call completeRequest immediately) until processing is done.
        // However, iOS might kill us if we take too long.

        // Show a spinner or blocking UI? SLComposeServiceViewController doesn't easily support that *after* post.
        // Usually, we start a background upload or process.
        // For local transcription, we must stay alive.

        let textContent = self.contentText ?? ""

        Task {
            do {
                var finalInputText = textContent

                // 1. Check for Audio Attachment
                if let audioURL = await findAudioAttachment() {
                    // Path 1: Audio -> WhisperKit -> AI
                    print("Found audio attachment at: \(audioURL)")

                    // Transcribe
                    // Note: This might take time.
                    let transcript = try await transcriberService.transcribe(audioURL: audioURL)
                    print("Transcription complete: \(transcript)")

                    // Append transcript to user's typed text (if any)
                    if !finalInputText.isEmpty {
                        finalInputText += "\n\n[Transcription]\n" + transcript
                    } else {
                        finalInputText = transcript
                    }
                }

                // 2. Setup checking for Text files if contentText is empty?
                // SLComposeServiceViewController usually puts text into contentText.
                // But just in case of a text FILE:
                if finalInputText.isEmpty, let textFileURL = await findTextFileAttachment() {
                    finalInputText = try String(contentsOf: textFileURL)
                }

                guard !finalInputText.isEmpty else {
                    // Nothing to process
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    return
                }

                // 3. Pass to AI
                let aiResponse = try await llmService.processJournalEntry(text: finalInputText)

                // 4. Save to Journal
                try await journalService.saveAIEntry(originalText: finalInputText, aiResponse: aiResponse)

                // Done
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)

            } catch {
                print("Error in Share Extension: \(error)")
                // It is hard to show error UI after "Post" is tapped as the view might dismiss.
                // But we can try to cancel the request with error.
                self.extensionContext?.cancelRequest(withError: error)
            }
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    // MARK: - Helpers

    private func findAudioAttachment() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                    return await loadURL(from: provider, typeIdentifier: UTType.audio.identifier)
                }
            }
        }
        return nil
    }

    private func findTextFileAttachment() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    // Avoid normal text sharing which fills contentText; look for files mostly
                    // But here we just return the URL if found
                    return await loadURL(from: provider, typeIdentifier: UTType.text.identifier)
                }
            }
        }
        return nil
    }

    private func loadURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (item, error) in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data {
                     // If it's data, write to temp file?
                    // Implementation simplicity: try to treat as URL first.
                    // Most file shares involve URL.
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
