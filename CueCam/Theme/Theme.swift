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

extension Color {
    /// Hex string like "#RRGGBB", used to persist a custom text color.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self = Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }

    /// Serializes to "#RRGGBB".
    func toHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

/// A calm, flat page background in the current reader theme. No glow, no gradient:
/// it should feel like paper, not a glossy app.
struct AppBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        palette.background
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: palette.background)
    }
}

extension View {
    /// A quiet, flat card: a solid surface fill with a hairline border and only a
    /// whisper of shadow. Adapts to the reader theme (light or dark).
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

private struct CardStyle: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return content
            .background(shape.fill(palette.card))
            .overlay(shape.stroke(palette.cardStroke, lineWidth: 1))
            .clipShape(shape)
            .shadow(color: .black.opacity(palette.isLight ? 0.05 : 0.18), radius: 8, x: 0, y: 3)
    }
}
