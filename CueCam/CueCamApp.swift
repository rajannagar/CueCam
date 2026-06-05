import SwiftUI

@main
struct CueCamApp: App {
    @StateObject private var store = ScriptStore()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootContainer()
                .environmentObject(store)
                .environmentObject(purchases)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    await purchases.start()
                }
        }
    }
}

/// Shows the animated splash on launch, then crossfades into the app.
private struct RootContainer: View {
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
    }
}
