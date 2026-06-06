import SwiftUI

/// App-wide theme state. The selected prompter theme also drives the whole app's
/// background and accent, so every page feels blended. Changing it anywhere updates
/// every screen because views observe this shared object.
@MainActor
final class ThemeManager: ObservableObject {
    static let key = "tp.theme"

    @Published var selected: PrompterTheme {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Self.key) }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? PrompterTheme.classic.rawValue
        selected = PrompterTheme(rawValue: raw) ?? .classic
    }

    var accent: Color { selected.appAccent }
    var accentDeep: Color { selected.appAccentDeep }
    var accentGradient: LinearGradient { selected.appAccentGradient }
}
