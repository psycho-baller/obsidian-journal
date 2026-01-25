import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Minimal UI - just show activity
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        activityIndicator.startAnimating()

        // Immediately handle the shared content
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        // Priority 1: Plain text (direct copy/paste sharing)
        if attachment.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
            attachment.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { [weak self] (data, error) in
                self?.handleLoadedItem(data: data, error: error)
            }
        }
        // Priority 2: File URL (sharing files from Files app, etc.)
        else if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
            attachment.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { [weak self] (data, error) in
                self?.handleLoadedItem(data: data, error: error)
            }
        }
        // Priority 3: Generic text type (covers various text formats)
        else if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (data, error) in
                self?.handleLoadedItem(data: data, error: error)
            }
        }
        // Priority 4: URL type (for web links shared as text)
        else if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
            attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { [weak self] (data, error) in
                self?.handleLoadedItem(data: data, error: error)
            }
        }
        else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func handleLoadedItem(data: NSSecureCoding?, error: Error?) {
        DispatchQueue.main.async {
            var text: String? = nil

            if let string = data as? String {
                text = string
            } else if let url = data as? URL {
                // Check if it's a file URL we can read
                if url.isFileURL {
                    text = try? String(contentsOf: url, encoding: .utf8)
                } else {
                    // It's a web URL, use its string representation
                    text = url.absoluteString
                }
            } else if let urlData = data as? Data, let urlString = String(data: urlData, encoding: .utf8) {
                text = urlString
            }

            guard let finalText = text, !finalText.isEmpty else {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            // Save to App Group UserDefaults (Backup for large content)
            if let defaults = UserDefaults(suiteName: "group.studio.orbitlabs.ignite") {
                defaults.set(finalText, forKey: "shared_content")
                defaults.synchronize()
            }

            // Open main app with content (Primary)
            var urlString = "ignite://open-shared"
            if let encoded = finalText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?content=\(encoded)"
            }

            if let url = URL(string: urlString) {
                self.openMainApp(url: url)
            }
        }
    }

    private func openMainApp(url: URL) {
        // Method 1: Responder chain approach
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }
            responder = responder?.next
        }

        // Method 2: Fallback for newer iOS versions
        self.extensionContext?.open(url, completionHandler: { [weak self] success in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
    }
}
