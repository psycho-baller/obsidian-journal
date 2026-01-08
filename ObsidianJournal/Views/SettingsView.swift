import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @StateObject private var llmService = LLMService()
    @State private var apiKey: String = ""
    @State private var isReInferring = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                // MARK: - AI Configuration
                Section(header: Text("AI Configuration")) {
                    SecureField("OpenAI API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Text("Your API key is stored securely on device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Template Status
                Section(header: Text("Daily Note Template")) {
                    if let template = vaultManager.inferredTemplate {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("Template Learned")
                                    .font(.subheadline)
                                Text("Confidence: \(Int(template.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let notes = template.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Variables: \(template.variables.map { $0.name }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.orange)
                            Text("No template learned yet")
                                .font(.subheadline)
                        }
                    }

                    Button(action: reInferTemplate) {
                        HStack {
                            if isReInferring {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isReInferring ? "Analyzing..." : "Re-analyze Templates")
                        }
                    }
                    .disabled(isReInferring)
                }

                // MARK: - Actions
                Section {
                    Button("Save Key") {
                        KeychainManager.shared.saveAPIKey(apiKey)
                        dismiss()
                    }
                    .disabled(apiKey.isEmpty)
                }

                // MARK: - Vault
                Section(header: Text("Vault")) {
                    if let url = vaultManager.vaultURL {
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Reset Vault", role: .destructive) {
                        vaultManager.reset()
                        vaultManager.clearTemplate()
                        dismiss()
                    }
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

    private func reInferTemplate() {
        isReInferring = true

        Task {
            do {
                let samples = try vaultManager.fetchRecentDailyNotes(count: 5)

                if !samples.isEmpty {
                    let template = try await llmService.inferTemplate(from: samples)
                    await MainActor.run {
                        vaultManager.saveTemplate(template)
                    }
                }
            } catch {
                // Error is logged by LLMService
            }

            await MainActor.run {
                isReInferring = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(VaultManager())
}
