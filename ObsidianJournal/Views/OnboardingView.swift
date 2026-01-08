import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject var vaultManager: VaultManager
    @StateObject private var llmService = LLMService()
    @State private var isShowingFolderPicker = false
    @State private var isInferringTemplate = false
    @State private var inferenceStatus: String = ""

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("Select Your Vault")
                .font(.title)
                .fontWeight(.bold)

            Text("Obsidian Journal needs permission to access your Daily Notes folder so we can save your journals directly.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundStyle(.secondary)

            if isInferringTemplate {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(inferenceStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                Button(action: {
                    isShowingFolderPicker = true
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("Select Folder")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            if let error = vaultManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handleVaultSelection(url)
                }
            case .failure(let error):
                vaultManager.error = error.localizedDescription
            }
        }
    }

    private func handleVaultSelection(_ url: URL) {
        // First, set the vault folder
        vaultManager.setVaultFolder(url)

        // Then, infer template from existing notes
        Task {
            await inferTemplate()
        }
    }

    @MainActor
    private func inferTemplate() async {
        isInferringTemplate = true
        inferenceStatus = "Analyzing your daily notes..."

        do {
            // Fetch recent daily notes
            let samples = try vaultManager.fetchRecentDailyNotes(count: 5)

            if samples.isEmpty {
                inferenceStatus = "No existing notes found. Using default template."
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s delay for UX
                isInferringTemplate = false
                return
            }

            inferenceStatus = "Found \(samples.count) notes. Learning your template..."

            // Infer template using AI
            let template = try await llmService.inferTemplate(from: samples)

            // Cache the template
            vaultManager.saveTemplate(template)

            inferenceStatus = "Template learned! Confidence: \(Int(template.confidence * 100))%"
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay to show success

        } catch {
            vaultManager.error = "Template inference failed: \(error.localizedDescription)"
        }

        isInferringTemplate = false
    }
}

#Preview {
    OnboardingView(vaultManager: VaultManager())
}
