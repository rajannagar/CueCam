import SwiftUI

/// Centralized look-and-feel. Keeping this in one place is what lets the app feel
/// consistent and "designed" rather than thrown together.
enum Theme {
    static let accent = Color(red: 0.45, green: 0.83, blue: 1.0)      // soft electric blue
    static let accentDeep = Color(red: 0.18, green: 0.55, blue: 0.95)

    static let bg = Color(red: 0.05, green: 0.06, blue: 0.09)
    static let surface = Color(red: 0.10, green: 0.11, blue: 0.15)
    static let surfaceHi = Color(red: 0.14, green: 0.16, blue: 0.21)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textFaint = Color.white.opacity(0.35)

    static let cardGradient = LinearGradient(
        colors: [surfaceHi, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Deep navy → blue used for the app badge / logo, matching the app icon.
    static let brandBadge = LinearGradient(
        colors: [Color(red: 0.06, green: 0.08, blue: 0.16), Color(red: 0.11, green: 0.30, blue: 0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// A subtle ambient backdrop — a soft accent glow over deep charcoal.
/// Flat black backgrounds read as "cheap"; this gives quiet depth.
struct AppBackground: View {
    @EnvironmentObject private var tm: ThemeManager

    var body: some View {
        ZStack {
            tm.selected.appBase
            RadialGradient(
                colors: [tm.selected.appGlow.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [tm.selected.appGlow.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: tm.selected)
    }
}

extension View {
    /// A reusable card container used throughout the app.
    func cardStyle() -> some View {
        self
            .background(Theme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}
