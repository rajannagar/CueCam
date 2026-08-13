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
        if let shot = ProcessInfo.processInfo.environment["TP_SHOT"] {
            return AnyView(ShotProbe(shot: shot))
        }
        return AnyView(content)
    }

    private var content: some View {
        ZStack {
            ScriptListView()
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Long enough to read the wordmark, short enough that launching
            // into your script never feels slow.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
        }
        .onChange(of: tm.selected) { _, theme in
            if matchIcon { applyAppIcon(AppIconOption.matching(theme)) }
        }
    }
}

private struct ShotProbe: View {
    @EnvironmentObject private var store: ScriptStore
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.palette) private var palette
    let shot: String
    init(shot: String) {
        self.shot = shot
        UserDefaults.standard.set(shot == "voice", forKey: "tp.voiceFollow")
    }
    private var sample: Script { store.scripts.first ?? Script(title: "Demo", body: "Hello") }
    var body: some View {
        Group {
            switch shot {
            case "prompter", "voice": TeleprompterView(script: sample)
            case "settings": SettingsView()
            case "editor": ScriptEditorView(script: sample)
            case "paywall": Color.clear.sheet(isPresented: .constant(true)) { PaywallView() }
            case "karaoke": KaraokeShot().background(palette.background.ignoresSafeArea())
            default: ScriptListView()
            }
        }
    }
}

private struct KaraokeShot: View {
    @StateObject private var engine = PrompterEngine()
    @Environment(\.palette) private var palette
    private let text = "This is the line you are reading right now.\n\nThe lines below stay dim until they reach the reading point, so your eyes never lose their place while you talk."
    var body: some View {
        PrompterCanvas(engine: engine, text: text, fontSize: 50, font: .serif,
                       textColor: palette.textPrimary, mirror: false, bold: false, karaoke: true)
            .onAppear { engine.startLink() }
    }
}
