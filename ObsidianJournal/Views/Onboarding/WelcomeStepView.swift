import SwiftUI

// MARK: - Step 1: Welcome (Clean & Enticing)

struct WelcomeStepView: View {
    var theme: AppTheme

    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showBadges = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo with glow
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .blur(radius: 40)

                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .opacity(showLogo ? 1 : 0)
                .scaleEffect(showLogo ? 1 : 0.8)

                // One powerful headline
                VStack(spacing: 8) {
                    Text("Speak your mind.")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)

                    Text("We'll handle the rest.")
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                }
                .multilineTextAlignment(.center)
                .opacity(showTitle ? 1 : 0)

                // Trust badges - simple row
                HStack(spacing: 24) {
                    trustBadge(icon: "lock.shield.fill", label: "Private")
                    trustBadge(icon: "bolt.fill", label: "Instant")
                    trustBadge(icon: "brain.head.profile", label: "Smart")
                }
                .opacity(showBadges ? 1 : 0)

                Spacer()

                NavigationLink(value: OnboardingStep.problem) {
                    Text("Get started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.actionPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                .opacity(showButton ? 1 : 0)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showLogo = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showBadges = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                showButton = true
            }
        }
    }

    private func trustBadge(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(theme.accent)

            Text(label)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeStepView(theme: ThemeManager.shared.currentTheme(for: .dark))
    }
}
