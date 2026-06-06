import SwiftUI

/// Visual themes for the prompter text. Free users get the first one; the rest are Pro.
enum PrompterTheme: String, CaseIterable, Identifiable {
    case classic, paper, mint, amber, rose, ocean, grape, sunset, contrast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .paper: return "Paper"
        case .mint: return "Mint"
        case .amber: return "Amber"
        case .rose: return "Rose"
        case .ocean: return "Ocean"
        case .grape: return "Grape"
        case .sunset: return "Sunset"
        case .contrast: return "Contrast"
        }
    }

    /// Available to free users without unlocking Pro.
    var isFree: Bool { self == .classic }

    var textColor: Color {
        switch self {
        case .classic: return .white
        case .paper: return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .mint: return Color(red: 0.80, green: 1.0, blue: 0.92)
        case .amber: return Color(red: 1.0, green: 0.86, blue: 0.62)
        case .rose: return Color(red: 1.0, green: 0.82, blue: 0.86)
        case .ocean: return Color(red: 0.78, green: 0.94, blue: 1.0)
        case .grape: return Color(red: 0.90, green: 0.84, blue: 1.0)
        case .sunset: return Color(red: 1.0, green: 0.88, blue: 0.80)
        case .contrast: return Color(red: 1.0, green: 0.92, blue: 0.30)
        }
    }

    /// Background for screen (non-camera) mode. Camera mode keeps the live feed behind the text.
    var background: Color {
        switch self {
        case .classic: return .black
        case .paper: return Color(red: 0.96, green: 0.95, blue: 0.91)
        case .mint: return Color(red: 0.04, green: 0.10, blue: 0.08)
        case .amber: return Color(red: 0.10, green: 0.07, blue: 0.02)
        case .rose: return Color(red: 0.10, green: 0.04, blue: 0.06)
        case .ocean: return Color(red: 0.02, green: 0.07, blue: 0.11)
        case .grape: return Color(red: 0.07, green: 0.04, blue: 0.11)
        case .sunset: return Color(red: 0.11, green: 0.05, blue: 0.06)
        case .contrast: return .black
        }
    }

    var swatch: Color { self == .paper ? Color(red: 0.96, green: 0.95, blue: 0.91) : textColor }

    /// Text color for camera mode. Over live video the background is unpredictable, so
    /// every theme uses a light, high-contrast color here (e.g. Paper's dark ink would
    /// be unreadable over video, so it becomes white).
    var cameraTextColor: Color {
        self == .paper ? .white : textColor
    }

    // MARK: - App-wide chrome palette
    // The whole app adopts the chosen theme so it feels blended. These stay dark
    // (so white UI text stays legible) but carry the theme's hue.

    /// Base background color for app pages (home, settings, editor, paywall).
    var appBase: Color {
        switch self {
        case .classic: return Color(red: 0.05, green: 0.06, blue: 0.09)
        case .paper:   return Color(red: 0.09, green: 0.085, blue: 0.075)
        case .mint:    return Color(red: 0.04, green: 0.085, blue: 0.07)
        case .amber:   return Color(red: 0.085, green: 0.065, blue: 0.035)
        case .rose:    return Color(red: 0.09, green: 0.05, blue: 0.065)
        case .ocean:   return Color(red: 0.03, green: 0.07, blue: 0.10)
        case .grape:   return Color(red: 0.07, green: 0.05, blue: 0.10)
        case .sunset:  return Color(red: 0.10, green: 0.055, blue: 0.05)
        case .contrast: return Color(red: 0.04, green: 0.04, blue: 0.05)
        }
    }

    /// Ambient glow tint layered over the base for depth.
    var appGlow: Color {
        switch self {
        case .classic: return Color(red: 0.45, green: 0.83, blue: 1.0)
        case .paper:   return Color(red: 0.95, green: 0.88, blue: 0.72)
        case .mint:    return Color(red: 0.45, green: 1.0, blue: 0.78)
        case .amber:   return Color(red: 1.0, green: 0.78, blue: 0.40)
        case .rose:    return Color(red: 1.0, green: 0.55, blue: 0.72)
        case .ocean:   return Color(red: 0.30, green: 0.78, blue: 1.0)
        case .grape:   return Color(red: 0.70, green: 0.50, blue: 1.0)
        case .sunset:  return Color(red: 1.0, green: 0.55, blue: 0.40)
        case .contrast: return Color(red: 1.0, green: 0.90, blue: 0.30)
        }
    }

    /// Accent used app-wide (buttons, sliders, highlights) so controls match the theme.
    var appAccent: Color {
        switch self {
        case .classic: return Color(red: 0.45, green: 0.83, blue: 1.0)
        case .paper:   return Color(red: 0.92, green: 0.80, blue: 0.55)
        case .mint:    return Color(red: 0.40, green: 0.95, blue: 0.72)
        case .amber:   return Color(red: 1.0, green: 0.74, blue: 0.36)
        case .rose:    return Color(red: 1.0, green: 0.52, blue: 0.70)
        case .ocean:   return Color(red: 0.30, green: 0.80, blue: 1.0)
        case .grape:   return Color(red: 0.72, green: 0.52, blue: 1.0)
        case .sunset:  return Color(red: 1.0, green: 0.58, blue: 0.40)
        case .contrast: return Color(red: 1.0, green: 0.90, blue: 0.25)
        }
    }

    var appAccentDeep: Color {
        switch self {
        case .classic: return Color(red: 0.18, green: 0.55, blue: 0.95)
        case .paper:   return Color(red: 0.74, green: 0.60, blue: 0.34)
        case .mint:    return Color(red: 0.20, green: 0.72, blue: 0.55)
        case .amber:   return Color(red: 0.90, green: 0.55, blue: 0.18)
        case .rose:    return Color(red: 0.88, green: 0.32, blue: 0.52)
        case .ocean:   return Color(red: 0.12, green: 0.52, blue: 0.85)
        case .grape:   return Color(red: 0.48, green: 0.30, blue: 0.85)
        case .sunset:  return Color(red: 0.88, green: 0.34, blue: 0.30)
        case .contrast: return Color(red: 0.85, green: 0.70, blue: 0.10)
        }
    }

    var appAccentGradient: LinearGradient {
        LinearGradient(colors: [appAccent, appAccentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum PrompterFont: String, CaseIterable, Identifiable {
    case rounded, standard, serif, mono, georgia, marker, script

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rounded: return "Rounded"
        case .standard: return "System"
        case .serif: return "Serif"
        case .mono: return "Mono"
        case .georgia: return "Georgia"
        case .marker: return "Marker"
        case .script: return "Script"
        }
    }

    /// PostScript/family name for named fonts; nil for built-in system designs.
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
