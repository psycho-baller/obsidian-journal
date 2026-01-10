import SwiftUI

// MARK: - App Theme Structure

struct AppTheme {
    let backgroundGradient: LinearGradient
    let cardBackground: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let success: Color
    let warning: Color
    let actionPrimary: Color
    let actionSecondary: Color
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // Obsidian's signature purple
    static let obsidianPurple = Color(hex: "#a882ff")

    // MARK: - Night Theme (Primary - Obsidian-Inspired)

    private static let nightObsidianTheme = AppTheme(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#1a1a2e"), // Deep dark purple-black
                Color(hex: "#16132b")  // Slightly lighter purple-black
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        cardBackground: Color(hex: "#2a2a42").opacity(0.85),
        textPrimary: .white,
        textSecondary: Color(hex: "#a3a3b8"),
        accent: obsidianPurple,
        success: Color(hex: "#4cd964"),
        warning: Color(hex: "#ffcc00"),
        actionPrimary: obsidianPurple,
        actionSecondary: Color(hex: "#3d3d5c")
    )

    // MARK: - Light Theme (Day Mode)

    private static let lightTheme = AppTheme(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#f5f5f7"),
                Color(hex: "#e8e8ed")
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        cardBackground: Color.white.opacity(0.9),
        textPrimary: Color(hex: "#1a1a2e"),
        textSecondary: Color(hex: "#6e6e80"),
        accent: obsidianPurple,
        success: Color(hex: "#34c759"),
        warning: Color(hex: "#ff9500"),
        actionPrimary: obsidianPurple,
        actionSecondary: Color.white.opacity(0.5)
    )

    // MARK: - Theme Mode

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }
    }

    @AppStorage("obsidianJournalThemeMode") var themeMode: ThemeMode = .dark {
        didSet { objectWillChange.send() }
    }

    var themeColor: Color {
        Self.obsidianPurple
    }

    func currentTheme(for scheme: ColorScheme) -> AppTheme {
        switch themeMode {
        case .light:
            return Self.lightTheme
        case .dark:
            return Self.nightObsidianTheme
        case .system:
            return scheme == .dark ? Self.nightObsidianTheme : Self.lightTheme
        }
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64, r: UInt64, g: UInt64, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
