import SwiftUI

// MARK: - Step 3: The Solution (Visual Transformation)

struct SolutionStepView: View {
    var theme: AppTheme

    @State private var showBefore = false
    @State private var showArrow = false
    @State private var showAfter = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Before → After Visual
                HStack(spacing: 20) {
                    // Before: Chaos
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#FF6B6B").opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "brain")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                        }

                        Text("Thoughts\nscattered")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(showBefore ? 1 : 0)
                    .offset(x: showBefore ? 0 : -20)

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.accent)
                        .opacity(showArrow ? 1 : 0)
                        .scaleEffect(showArrow ? 1 : 0.5)

                    // After: Organized
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#4CD964").opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#4CD964"))
                        }

                        Text("Perfectly\norganized")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(showAfter ? 1 : 0)
                    .offset(x: showAfter ? 0 : 20)
                }

                // The headline
                VStack(spacing: 8) {
                    Text("Speak. We organize.")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                }
                .opacity(showAfter ? 1 : 0)

                // The magic: Visual flow
                VStack(spacing: 0) {
                    flowStep(icon: "waveform", label: "You speak", isFirst: true)
                    flowConnector()
                    flowStep(icon: "text.alignleft", label: "AI transcribes", isFirst: false)
                    flowConnector()
                    flowStep(icon: "doc.badge.gearshape", label: "Finds the right spot", isFirst: false)
                    flowConnector()
                    flowStep(icon: "checkmark.circle.fill", label: "Done", isFirst: false, isLast: true)
                }
                .padding(.horizontal, 40)
                .opacity(showAfter ? 1 : 0)

                Spacer()

                NavigationLink(value: OnboardingStep.features) {
                    Text("See it in action")
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
            withAnimation(.easeOut(duration: 0.4)) {
                showBefore = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
                showArrow = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                showAfter = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
                showButton = true
            }
        }
    }

    private func flowStep(icon: String, label: String, isFirst: Bool, isLast: Bool = false) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isLast ? Color(hex: "#4CD964").opacity(0.2) : theme.accent.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isLast ? Color(hex: "#4CD964") : theme.accent)
            }

            Text(label)
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)

            Spacer()
        }
    }

    private func flowConnector() -> some View {
        HStack {
            Rectangle()
                .fill(theme.accent.opacity(0.3))
                .frame(width: 2, height: 20)
                .padding(.leading, 21)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        SolutionStepView(theme: ThemeManager.shared.currentTheme(for: .dark))
    }
}
