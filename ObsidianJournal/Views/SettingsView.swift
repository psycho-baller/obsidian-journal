import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Configuration")) {
                    SecureField("OpenAI API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Text("Your API key is stored securely on device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Save Key") {
                        KeychainManager.shared.saveAPIKey(apiKey)
                        dismiss()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let key = KeychainManager.shared.getAPIKey() {
                    apiKey = key
                }
            }
        }
    }
}
