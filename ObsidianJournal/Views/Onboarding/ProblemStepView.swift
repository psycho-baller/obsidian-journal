import SwiftUI

// MARK: - Step 2: The Pain (Visual-First)

struct ProblemStepView: View {
    var theme: AppTheme

    @State private var showContent = false
    @State private var showVisual = false
    @State private var showButton = false
    @State private var ideaOpacity: Double = 1.0

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // The visual metaphor: Ideas fading away
                ZStack {
                    // Fading thought bubbles
                    ForEach(0..<3, id: \.self) { index in
                        ThoughtBubble(
                            icon: ["lightbulb.fill", "star.fill", "bolt.fill"][index],
                            color: [theme.accent, Color(hex: "#FFD700"), Color(hex: "#FF6B6B")][index],
                            offset: CGSize(width: [-60, 60, 0][index], height: [-40, -30, 40][index]),
                            delay: Double(index) * 0.3
                        )
                    }
                }
                .frame(height: 160)
                .opacity(showVisual ? 1 : 0)

                // One powerful headline
                VStack(spacing: 12) {
                    Text("Your best ideas")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)

                    Text("disappear before you can capture them.")
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .opacity(showContent ? 1 : 0)

                // Simple pain indicators (icons, not paragraphs)
                HStack(spacing: 30) {
                    painIndicator(icon: "clock.fill", label: "Too slow")
                    painIndicator(icon: "keyboard", label: "Too clunky")
                    painIndicator(icon: "brain", label: "Breaks flow")
                }
                .opacity(showVisual ? 1 : 0)

                Spacer()

                NavigationLink(value: OnboardingStep.solution) {
                    Text("There's a better way")
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showVisual = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showButton = true
            }
        }
    }

    private func painIndicator(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "#FF6B6B"))

            Text(label)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - Animated Thought Bubble

private struct ThoughtBubble: View {
    let icon: String
    let color: Color
    let offset: CGSize
    let delay: Double

    @State private var isVisible = false
    @State private var isFading = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 60, height: 60)
                .blur(radius: 10)

            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
        }
        .offset(offset)
        .opacity(isFading ? 0.2 : (isVisible ? 1 : 0))
        .scaleEffect(isVisible ? 1 : 0.5)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                isVisible = true
            }
            // Start fading animation after appearing
            withAnimation(.easeInOut(duration: 2).delay(delay + 1).repeatForever(autoreverses: true)) {
                isFading = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProblemStepView(theme: ThemeManager.shared.currentTheme(for: .dark))
    }
}
