import SwiftUI

/// Contextual settings shown from inside either prompter (the "sliders" sheet):
/// theme, font, countdown, mirror, and voice-follow. Pro-only options route to the paywall.
struct PrompterSettingsSheet: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("tp.theme") private var themeRaw = PrompterTheme.classic.rawValue
    @AppStorage("tp.font") private var fontRaw = PrompterFont.rounded.rawValue
    @AppStorage("tp.countdown") private var countdownEnabled = true
    @AppStorage("tp.mirror") private var mirror = false
    @AppStorage("tp.voiceFollow") private var voiceFollow = false

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        themeSection
                        fontSection
                        togglesSection
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Prompter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Theme")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(PrompterTheme.allCases) { theme in
                    Button {
                        if theme.isFree || purchases.isPro {
                            themeRaw = theme.rawValue
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(theme.background)
                                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                                Text("Aa")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.textColor)
                                if !theme.isFree && !purchases.isPro {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                        .offset(x: 14, y: -14)
                                }
                            }
                            .frame(height: 46)
                            .overlay(
                                Circle().stroke(Theme.accent, lineWidth: themeRaw == theme.rawValue ? 2.5 : 0)
                            )
                            Text(theme.title)
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Font")
            HStack(spacing: 10) {
                ForEach(PrompterFont.allCases) { f in
                    Button {
                        fontRaw = f.rawValue
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        Text("Aa")
                            .font(.system(size: 18, weight: .semibold, design: f.design))
                            .foregroundStyle(fontRaw == f.rawValue ? .black : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(fontRaw == f.rawValue ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var togglesSection: some View {
        VStack(spacing: 4) {
            toggleRow("timer", "3-2-1 countdown", isOn: $countdownEnabled, locked: false)
            Divider().overlay(Color.white.opacity(0.06))
            proToggleRow("rectangle.lefthalf.filled", "Mirror mode", isOn: $mirror)
            Divider().overlay(Color.white.opacity(0.06))
            proToggleRow("waveform", "Voice-follow scrolling", isOn: $voiceFollow)
        }
        .padding(16)
        .cardStyle()
    }

    private func toggleRow(_ icon: String, _ title: String, isOn: Binding<Bool>, locked: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 26)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Theme.accent)
        }
        .padding(.vertical, 6)
    }

    private func proToggleRow(_ icon: String, _ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 26)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
            Spacer()
            if purchases.isPro {
                Toggle("", isOn: isOn).labelsHidden().tint(Theme.accent)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.caption2)
                        Text("Pro").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.accentGradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textFaint)
            .tracking(0.5)
    }
}
