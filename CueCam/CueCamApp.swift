import SwiftUI

@main
struct CueCamApp: App {
    @StateObject private var store = ScriptStore()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootContainer()
                .environmentObject(store)
                .environmentObject(purchases)
                .environmentObject(theme)
                .environment(\.palette, theme.palette)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.accent)
                .task {
                    await purchases.start()
                }
        }
    }
}

/// Shows the animated splash on launch, then crossfades into the app.
private struct RootContainer: View {
    @EnvironmentObject private var tm: ThemeManager
    @AppStorage("tp.matchIcon") private var matchIcon = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ScriptListView()
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            withAnimation(.easeInOut(duration: 0.55)) { showSplash = false }
        }
        .onChange(of: tm.selected) { _, theme in
            if matchIcon { applyAppIcon(AppIconOption.matching(theme)) }
        }
    }
}
