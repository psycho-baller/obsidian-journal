import SwiftUI

struct ContentView: View {
    @StateObject private var vaultManager = VaultManager()

    var body: some View {
        Group {
            if vaultManager.isVaultConfigured {
                MainJournalView(vaultManager: vaultManager)
            } else {
                OnboardingView(vaultManager: vaultManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
