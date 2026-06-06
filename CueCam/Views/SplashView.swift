import SwiftUI

/// Animated brand splash shown briefly at launch - wordmark only.
struct SplashView: View {
    @State private var nameIn = false
    @State private var taglineIn = false
    @State private var glow = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 10) {
                Text("CueCam")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .shadow(color: Theme.accent.opacity(glow ? 0.5 : 0.15), radius: glow ? 26 : 10)
                    .scaleEffect(nameIn ? 1 : 0.8)
                    .opacity(nameIn ? 1 : 0)

                Text("Your pocket teleprompter")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .opacity(taglineIn ? 1 : 0)
                    .offset(y: taglineIn ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { nameIn = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { taglineIn = true }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
