import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject var vaultManager: VaultManager
    @State private var isShowingFolderPicker = false

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
                    vaultManager.setVaultFolder(url)
                }
            case .failure(let error):
                vaultManager.error = error.localizedDescription
            }
        }
    }
}

#Preview {
    OnboardingView(vaultManager: VaultManager())
}
