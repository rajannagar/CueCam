import SwiftUI

/// App-wide theme state. The selected reader appearance drives the whole app: its
/// background, surfaces, text, and accent. Changing it anywhere updates every screen
/// because views observe this shared object.
@MainActor
final class ThemeManager: ObservableObject {
    static let key = "tp.theme"

    @Published var selected: PrompterTheme {
        didSet {
            UserDefaults.standard.set(selected.rawValue, forKey: Self.key)
            if oldValue != selected {
                UserDefaults.standard.removeObject(forKey: "tp.textColorHex")
            }
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? PrompterTheme.paper.rawValue
        selected = PrompterTheme(rawValue: raw) ?? .paper
    }

    var palette: ReaderPalette { selected.palette }
    var isLight: Bool { palette.isLight }
    var colorScheme: ColorScheme { palette.isLight ? .light : .dark }

    var bg: Color { palette.background }
    var surface: Color { palette.surface }
    var textPrimary: Color { palette.textPrimary }
    var textSecondary: Color { palette.textSecondary }
    var textFaint: Color { palette.textFaint }
    var accent: Color { palette.accent }
    var accentDeep: Color { palette.accentDeep }
    var accentGradient: LinearGradient { palette.accentGradient }
}

// MARK: - Palette in the environment (so cardStyle can adapt without threading state)

private struct ReaderPaletteKey: EnvironmentKey {
    static let defaultValue = PrompterTheme.paper.palette
}

extension EnvironmentValues {
    var palette: ReaderPalette {
        get { self[ReaderPaletteKey.self] }
        set { self[ReaderPaletteKey.self] = newValue }
    }
}
