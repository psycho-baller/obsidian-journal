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
        // 1. Grab the item (e.g., plain text)
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first else {
            // No attachments found, just complete
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        // Check for plain text (using the legacy kUTTypePlainText for compatibility)
        if attachment.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
            attachment.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { [weak self] (data, error) in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    if let text = data as? String {
                        // 2. Save to App Group UserDefaults (more reliable than URL encoding for large text)
                        if let defaults = UserDefaults(suiteName: "group.studio.orbitlabs.ignite") {
                            defaults.set(text, forKey: "shared_content")
                            defaults.synchronize()
                        }

                        // 3. Open main app
                        if let url = URL(string: "ignite://open-shared") {
                            self.openMainApp(url: url)
                        }
                    } else {
                        // Failed to extract text
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                }
            }
        } else if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            // Fallback: Try UTType.text (covers more text types)
            attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (data, error) in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    var text: String? = nil

                    if let string = data as? String {
                        text = string
                    } else if let url = data as? URL {
                        text = try? String(contentsOf: url)
                    }

                    if let text = text {
                        if let defaults = UserDefaults(suiteName: "group.studio.orbitlabs.ignite") {
                            defaults.set(text, forKey: "shared_content")
                            defaults.synchronize()
                        }

                        if let url = URL(string: "ignite://open-shared") {
                            self.openMainApp(url: url)
                        }
                    } else {
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                }
            }
        } else {
            // Unknown type, just complete
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
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

        // Method 2: Fallback for newer iOS versions - use extensionContext.open directly
        self.extensionContext?.open(url, completionHandler: { [weak self] success in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
    }
}
