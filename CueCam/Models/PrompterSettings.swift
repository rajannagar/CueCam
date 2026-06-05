import SwiftUI

/// Visual themes for the prompter text. Free users get the first one; the rest are Pro.
enum PrompterTheme: String, CaseIterable, Identifiable {
    case classic, paper, mint, amber, rose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .paper: return "Paper"
        case .mint: return "Mint"
        case .amber: return "Amber"
        case .rose: return "Rose"
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
        }
    }

    var swatch: Color { self == .paper ? Color(red: 0.96, green: 0.95, blue: 0.91) : textColor }
}

enum PrompterFont: String, CaseIterable, Identifiable {
    case rounded, standard, serif, mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rounded: return "Rounded"
        case .standard: return "System"
        case .serif: return "Serif"
        case .mono: return "Mono"
        }
    }

    var design: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .standard: return .default
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }
}
