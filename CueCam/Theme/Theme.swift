import SwiftUI

extension View {
    /// A teleprompter must never auto-lock mid-read: the reader's hands are busy
    /// and the screen sits untouched for minutes. Keeps the display awake while
    /// this view is on screen, and restores normal locking when it goes away.
    func keepsScreenAwake() -> some View {
        onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
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
