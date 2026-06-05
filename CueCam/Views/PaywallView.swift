import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    private let features: [(String, String, String)] = [
        ("infinity", "Unlimited scripts", "Save as many as you want, no caps."),
        ("waveform", "Voice-follow scrolling", "The script moves as you speak. On-device, private."),
        ("paintbrush.pointed.fill", "Themes & fonts", "Five themes and four typefaces to read your way."),
        ("rectangle.lefthalf.filled", "Mirror mode", "Flip text for beam-splitter camera rigs.")
    ]

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                closeButton
                ScrollView {
                    VStack(spacing: 26) {
                        header
                        featureList
                    }
                    .padding(24)
                }
                purchaseFooter
            }
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(12)
            }
        }
        .padding(.trailing, 8)
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 46))
                .foregroundStyle(Theme.accentGradient)
            Text("CueCam Pro")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text("A one-time unlock. No subscription, ever.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var featureList: some View {
        VStack(spacing: 14) {
            ForEach(features, id: \.0) { feature in
                HStack(spacing: 16) {
                    Image(systemName: feature.0)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.1)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(feature.2)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
        }
    }

    private var purchaseFooter: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchases.purchase(); if purchases.isPro { dismiss() } }
            } label: {
                HStack {
                    if purchases.isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text("Unlock Pro · \(purchases.priceText)")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accentGradient, in: Capsule())
                .foregroundStyle(.black)
            }
            .disabled(purchases.isLoading)

            Button("Restore Purchase") {
                Task { await purchases.restore(); if purchases.isPro { dismiss() } }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)

            Text("One-time payment. Yours forever on this Apple ID.")
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
        }
        .padding(20)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
    }
}
