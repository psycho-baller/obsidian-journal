import SwiftUI

struct ContentView: View {
    @StateObject private var vaultManager = VaultManager()

    var body: some View {
        Group {
            if vaultManager.isVaultConfigured && !vaultManager.showOnboarding {
                MainEditorView()
                    .environmentObject(vaultManager)
                    .environmentObject(JournalService(vaultManager: vaultManager))
            } else {
                OnboardingView(vaultManager: vaultManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
