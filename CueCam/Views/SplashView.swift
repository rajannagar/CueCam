import SwiftUI

/// Animated brand splash shown briefly at launch.
struct SplashView: View {
    @State private var logoIn = false
    @State private var textIn = false
    @State private var glow = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 22) {
                CueCamLogo()
                    .frame(width: 116, height: 116)
                    .shadow(color: Theme.accent.opacity(glow ? 0.55 : 0.2), radius: glow ? 30 : 12)
                    .scaleEffect(logoIn ? 1 : 0.6)
                    .opacity(logoIn ? 1 : 0)

                VStack(spacing: 8) {
                    Text("CueCam")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Your pocket teleprompter")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .opacity(textIn ? 1 : 0)
                .offset(y: textIn ? 0 : 14)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) { logoIn = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) { textIn = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
