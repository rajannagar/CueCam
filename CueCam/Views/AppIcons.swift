import SwiftUI
import UIKit

/// The selectable app icons. `sepia` is the primary (nil alternate name); the rest are
/// alternate icons bundled in the asset catalog and listed in the build settings under
/// ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
enum AppIconOption: String, CaseIterable, Identifiable {
    case sepia, ivory, charcoal, classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sepia: return "Sepia"
        case .ivory: return "Ivory"
        case .charcoal: return "Charcoal"
        case .classic: return "Classic"
        }
    }

    /// Asset catalog name; nil means the primary icon.
    var iconName: String? {
        switch self {
        case .sepia: return nil
        case .ivory: return "AppIcon-Ivory"
        case .charcoal: return "AppIcon-Charcoal"
        case .classic: return "AppIcon-Classic"
        }
    }

    static func from(iconName: String?) -> AppIconOption {
        allCases.first { $0.iconName == iconName } ?? .sepia
    }

    /// The icon that best matches a reader theme (for "match icon to theme").
    static func matching(_ theme: PrompterTheme) -> AppIconOption {
        switch theme {
        case .paper: return .sepia
        case .ivory: return .ivory
        case .sepia: return .sepia
        case .charcoal, .night: return .charcoal
        case .classic: return .classic
        }
    }

    // Preview colors, matching the rendered PNGs.
    var bg: [Color] {
        switch self {
        case .sepia:    return [rgb(0.62, 0.42, 0.22), rgb(0.34, 0.21, 0.10)]
        case .ivory:    return [rgb(0.97, 0.95, 0.90), rgb(0.89, 0.85, 0.77)]
        case .charcoal: return [rgb(0.17, 0.16, 0.14), rgb(0.08, 0.075, 0.065)]
        case .classic:  return [rgb(0.07, 0.07, 0.07), .black]
        }
    }
    var line: Color {
        switch self {
        case .sepia:    return rgb(0.965, 0.937, 0.871)
        case .ivory:    return rgb(0.55, 0.37, 0.20)
        case .charcoal: return rgb(0.88, 0.64, 0.34)
        case .classic:  return .white
        }
    }
    var tri: Color {
        switch self {
        case .sepia:    return rgb(0.98, 0.91, 0.76)
        case .ivory:    return rgb(0.62, 0.42, 0.24)
        case .charcoal: return rgb(0.92, 0.72, 0.42)
        case .classic:  return rgb(0.44, 0.71, 0.92)
        }
    }

    private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
}

@MainActor
func applyAppIcon(_ option: AppIconOption) {
    guard UIApplication.shared.supportsAlternateIcons else { return }
    guard UIApplication.shared.alternateIconName != option.iconName else { return }
    UIApplication.shared.setAlternateIconName(option.iconName)
}

/// A vector preview of an app icon (mirrors the rendered PNG) for the picker.
struct IconArtwork: View {
    let option: AppIconOption

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.22, style: .continuous)
                    .fill(LinearGradient(colors: option.bg, startPoint: .topLeading, endPoint: .bottomTrailing))
                Capsule().fill(option.line).frame(width: w * 0.52, height: w * 0.075).position(x: w/2, y: w*0.38)
                Capsule().fill(option.line.opacity(0.8)).frame(width: w * 0.42, height: w * 0.075).position(x: w/2, y: w*0.52)
                Capsule().fill(option.line.opacity(0.58)).frame(width: w * 0.32, height: w * 0.075).position(x: w/2, y: w*0.66)
                Triangle().fill(option.tri).frame(width: w*0.075, height: w*0.10)
                    .rotationEffect(.degrees(90)).position(x: w*0.14, y: w*0.38)
                Triangle().fill(option.tri).frame(width: w*0.075, height: w*0.10)
                    .rotationEffect(.degrees(-90)).position(x: w*0.86, y: w*0.38)
            }
            .frame(width: w, height: w)
        }
    }
}
