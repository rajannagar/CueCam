import SwiftUI

struct SettingsView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var tm: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var currentIcon: AppIconOption = .sepia
    @AppStorage("tp.matchIcon") private var matchIcon = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        brandHeader
                        statusCard
                        prompterSection
                        iconSection
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
            .onAppear { currentIcon = AppIconOption.from(iconName: UIApplication.shared.alternateIconName) }
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APP ICON")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textFaint)
                .tracking(0.5)
                .padding(.leading, 4)

            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ForEach(AppIconOption.allCases) { option in
                        Button {
                            applyAppIcon(option)
                            currentIcon = option
                        } label: {
                            VStack(spacing: 6) {
                                IconArtwork(option: option)
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .stroke(palette.accent, lineWidth: currentIcon == option ? 2.5 : 0)
                                    )
                                Text(option.title)
                                    .font(.caption2)
                                    .foregroundStyle(palette.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .disabled(matchIcon)
                        .opacity(matchIcon ? 0.4 : 1)
                        .accessibilityLabel("\(option.title) app icon")
                        .accessibilityAddTraits(currentIcon == option ? .isSelected : [])
                    }
                }

                Divider().overlay(palette.cardStroke)

                HStack(spacing: 14) {
                    Image(systemName: "wand.and.stars").foregroundStyle(palette.accent).frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Match icon to theme")
                            .font(.subheadline.weight(.medium)).foregroundStyle(palette.textPrimary)
                        Text("Switches the icon when you change theme.")
                            .font(.caption).foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $matchIcon).labelsHidden().tint(palette.accent)
                        .accessibilityLabel("Match icon to theme")
                }
                .onChange(of: matchIcon) { _, on in
                    if on { applyAppIcon(AppIconOption.matching(tm.selected)); currentIcon = AppIconOption.matching(tm.selected) }
                }
            }
            .padding(16)
            .cardStyle()
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 6) {
            Text("CueCam")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
            Text("Your pocket teleprompter")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var prompterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROMPTER DEFAULTS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textFaint)
                .tracking(0.5)
                .padding(.leading, 4)
            PrompterPreferences()
        }
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Text("CueCam")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textSecondary)
            Text("Version \(appVersion)")
                .font(.caption2)
                .foregroundStyle(palette.textFaint)
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
                        .font(.subheadline.weight(.semibold)).foregroundStyle(palette.textPrimary)
                    Text("Test toggle. Not in the App Store build.")
                        .font(.caption).foregroundStyle(palette.textSecondary)
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
                        .foregroundStyle(palette.textPrimary)
                    Text(purchases.isPro ? "Thanks for your support." : "Up to \(ScriptStore.freeLimit) scripts.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
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
                .foregroundStyle(palette.textSecondary)
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
                .foregroundStyle(palette.textSecondary)
            Spacer()
        }
    }
}
