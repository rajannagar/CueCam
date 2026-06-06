import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var tm: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        brandHeader
                        statusCard
                        prompterSection
                        infoCard
                        #if DEBUG
                        debugCard
                        #endif
                        aboutFooter
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 6) {
            Text("CueCam")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Your pocket teleprompter")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var prompterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROMPTER DEFAULTS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textFaint)
                .tracking(0.5)
                .padding(.leading, 4)
            PrompterPreferences()
        }
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Text("CueCam")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Text("Version \(appVersion)")
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    #if DEBUG
    private var debugCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: "hammer.fill").foregroundStyle(.orange).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    Text("Test toggle. Not in the App Store build.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { purchases.isPro },
                    set: { purchases.debugSetPro($0) }
                ))
                .labelsHidden()
                .tint(.orange)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
    #endif

    private var statusCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: purchases.isPro ? "checkmark.seal.fill" : "sparkles")
                    .font(.title2)
                    .foregroundStyle(tm.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(purchases.isPro ? "Pro unlocked" : "Free plan")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(purchases.isPro ? "Thanks for your support." : "Up to \(ScriptStore.freeLimit) scripts.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            if !purchases.isPro {
                Button {
                    showPaywall = true
                } label: {
                    Text("Unlock Pro · \(purchases.priceText)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(tm.accentGradient, in: Capsule())
                        .foregroundStyle(.black)
                }
                Button("Restore Purchase") {
                    Task { await purchases.restore() }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("text.alignleft", "Paste a script, hit play, read.")
            row("hand.tap", "Tap the screen to pause or resume.")
            row("hand.draw", "Drag up or down to reposition.")
            row("lock.shield", "Everything stays on your device.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(tm.accent)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }
}
