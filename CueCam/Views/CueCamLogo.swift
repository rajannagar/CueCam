import SwiftUI

/// The CueCam app mark — a rounded badge with three tapering teleprompter lines and
/// focal triangles, matching the App Store icon. Scales to whatever frame it's given.
struct CueCamLogo: View {
    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.23, style: .continuous)
                    .fill(Theme.brandBadge)
                    .overlay(
                        RoundedRectangle(cornerRadius: w * 0.23, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )

                // Tapering lines
                Capsule().fill(Theme.accent)
                    .frame(width: w * 0.50, height: w * 0.075).position(x: w / 2, y: w * 0.38)
                Capsule().fill(Theme.accent.opacity(0.7))
                    .frame(width: w * 0.40, height: w * 0.075).position(x: w / 2, y: w * 0.52)
                Capsule().fill(Theme.accent.opacity(0.45))
                    .frame(width: w * 0.30, height: w * 0.075).position(x: w / 2, y: w * 0.66)

                // Focal triangles flanking the top line
                Triangle().fill(Theme.accent)
                    .frame(width: w * 0.075, height: w * 0.10)
                    .rotationEffect(.degrees(90)).position(x: w * 0.15, y: w * 0.38)
                Triangle().fill(Theme.accent)
                    .frame(width: w * 0.075, height: w * 0.10)
                    .rotationEffect(.degrees(-90)).position(x: w * 0.85, y: w * 0.38)
            }
            .frame(width: w, height: w)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The wordmark: logo + "CueCam" set in rounded type. Used in headers.
struct CueCamWordmark: View {
    var logoSize: CGFloat = 26
    var fontSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 9) {
            CueCamLogo().frame(width: logoSize, height: logoSize)
            Text("CueCam")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
