import SwiftUI
import UniformTypeIdentifiers

/// Legacy OnboardingView - now redirects to the new multi-step onboarding flow.
/// This file is kept for backward compatibility but the main flow is in Onboarding/OnboardingContainerView.swift
struct OnboardingView: View {
    @ObservedObject var vaultManager: VaultManager

    var body: some View {
        OnboardingContainerView(vaultManager: vaultManager)
    }
}

#Preview {
    OnboardingView(vaultManager: VaultManager())
}
