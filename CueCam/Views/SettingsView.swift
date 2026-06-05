import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    @AppStorage("tp.countdown") private var countdownEnabled: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        statusCard
                        playbackCard
                        infoCard
                        #if DEBUG
                        debugCard
                        #endif
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
                    .foregroundStyle(Theme.accent)
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
                        .background(Theme.accentGradient, in: Capsule())
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

    private var playbackCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("3-2-1 countdown")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("A moment to settle before the words move.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $countdownEnabled)
                    .labelsHidden()
                    .tint(Theme.accent)
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
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }
}
