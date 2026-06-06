import SwiftUI

/// A full app-wide color palette for a reader appearance. Each theme is either light
/// or dark, and the whole app (home, settings, editor, prompter) adopts it so CueCam
/// feels like an e-reader rather than a dark utility app.
struct ReaderPalette {
    let isLight: Bool
    let background: Color   // page background
    let surface: Color      // slightly offset background for layering
    let card: Color         // card fill
    let cardStroke: Color   // hairline border
    let textPrimary: Color
    let textSecondary: Color
    let textFaint: Color
    let accent: Color
    let accentDeep: Color

    var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Over live video a light ink would vanish, so light themes read white on camera.
    var cameraText: Color { isLight ? .white : textPrimary }
}

/// Reader appearances. Warm and calm by default, with light and dark options so the
/// reader can pick what's easy on their eyes.
enum PrompterTheme: String, CaseIterable, Identifiable {
    case paper, ivory, sepia, charcoal, classic, night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paper: return "Paper"
        case .ivory: return "Ivory"
        case .sepia: return "Sepia"
        case .charcoal: return "Charcoal"
        case .classic: return "Classic"
        case .night: return "Night"
        }
    }

    /// Paper (the warm default) is free; the rest are Pro.
    var isFree: Bool { self == .paper }

    var palette: ReaderPalette {
        switch self {
        case .paper:
            return ReaderPalette(
                isLight: true,
                background: rgb(0.957, 0.925, 0.855),
                surface: rgb(0.937, 0.902, 0.824),
                card: rgb(0.984, 0.957, 0.890),
                cardStroke: Color.black.opacity(0.08),
                textPrimary: rgb(0.173, 0.149, 0.125),
                textSecondary: rgb(0.431, 0.388, 0.325),
                textFaint: rgb(0.663, 0.616, 0.533),
                accent: rgb(0.604, 0.416, 0.235),
                accentDeep: rgb(0.467, 0.306, 0.161)
            )
        case .ivory:
            return ReaderPalette(
                isLight: true,
                background: rgb(0.980, 0.976, 0.965),
                surface: rgb(0.949, 0.945, 0.933),
                card: .white,
                cardStroke: Color.black.opacity(0.07),
                textPrimary: rgb(0.106, 0.106, 0.114),
                textSecondary: rgb(0.431, 0.431, 0.451),
                textFaint: rgb(0.690, 0.690, 0.710),
                accent: rgb(0.235, 0.431, 0.612),
                accentDeep: rgb(0.157, 0.314, 0.435)
            )
        case .sepia:
            return ReaderPalette(
                isLight: true,
                background: rgb(0.910, 0.851, 0.737),
                surface: rgb(0.882, 0.816, 0.690),
                card: rgb(0.945, 0.902, 0.804),
                cardStroke: Color.black.opacity(0.09),
                textPrimary: rgb(0.227, 0.180, 0.118),
                textSecondary: rgb(0.435, 0.361, 0.251),
                textFaint: rgb(0.643, 0.561, 0.424),
                accent: rgb(0.541, 0.353, 0.169),
                accentDeep: rgb(0.420, 0.267, 0.125)
            )
        case .charcoal:
            return ReaderPalette(
                isLight: false,
                background: rgb(0.102, 0.102, 0.094),
                surface: rgb(0.129, 0.122, 0.110),
                card: rgb(0.149, 0.141, 0.125),
                cardStroke: Color.white.opacity(0.08),
                textPrimary: rgb(0.925, 0.902, 0.855),
                textSecondary: rgb(0.659, 0.627, 0.588),
                textFaint: rgb(0.431, 0.404, 0.365),
                accent: rgb(0.878, 0.643, 0.345),
                accentDeep: rgb(0.725, 0.498, 0.235)
            )
        case .classic:
            return ReaderPalette(
                isLight: false,
                background: .black,
                surface: rgb(0.055, 0.055, 0.055),
                card: rgb(0.086, 0.086, 0.086),
                cardStroke: Color.white.opacity(0.10),
                textPrimary: .white,
                textSecondary: Color.white.opacity(0.62),
                textFaint: Color.white.opacity(0.34),
                accent: rgb(0.435, 0.714, 0.918),
                accentDeep: rgb(0.243, 0.525, 0.753)
            )
        case .night:
            return ReaderPalette(
                isLight: false,
                background: rgb(0.078, 0.090, 0.110),
                surface: rgb(0.098, 0.114, 0.141),
                card: rgb(0.122, 0.141, 0.173),
                cardStroke: Color.white.opacity(0.08),
                textPrimary: rgb(0.863, 0.890, 0.925),
                textSecondary: rgb(0.592, 0.631, 0.682),
                textFaint: rgb(0.369, 0.404, 0.447),
                accent: rgb(0.510, 0.663, 0.808),
                accentDeep: rgb(0.329, 0.494, 0.651)
            )
        }
    }

    // Convenience accessors used around the app.
    var textColor: Color { palette.textPrimary }
    var background: Color { palette.background }
    var cameraTextColor: Color { palette.cameraText }
    var swatch: Color { palette.background }

    private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }
}

enum PrompterFont: String, CaseIterable, Identifiable {
    case serif, rounded, standard, mono, georgia, marker, script

    var id: String { rawValue }

    /// The three fonts available without Pro.
    var isFree: Bool { self == .serif || self == .rounded || self == .standard }

    var title: String {
        switch self {
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .standard: return "System"
        case .mono: return "Mono"
        case .georgia: return "Georgia"
        case .marker: return "Marker"
        case .script: return "Script"
        }
    }

    private var customName: String? {
        switch self {
        case .georgia: return "Georgia"
        case .marker: return "Marker Felt"
        case .script: return "Snell Roundhand"
        default: return nil
        }
    }

    private var design: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono: return .monospaced
        default: return .default
        }
    }

    /// Resolves to a SwiftUI Font. Named fonts fall back to the system silently if
    /// unavailable, so this is always safe.
    func font(size: CGFloat, bold: Bool) -> Font {
        if let name = customName {
            return Font.custom(name, size: size).weight(bold ? .bold : .regular)
        }
        return .system(size: size, weight: bold ? .heavy : .semibold, design: design)
    }
}
