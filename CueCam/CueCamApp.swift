import SwiftUI

@main
struct CueCamApp: App {
    @StateObject private var store = ScriptStore()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            ScriptListView()
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
