import SwiftUI

/// Shown when creating a new script: start blank or from a ready-made template.
struct TemplatePickerView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var tm: ThemeManager
    @Environment(\.dismiss) private var dismiss

    /// Called with the chosen starting script (blank or template-filled).
    let onPick: (Script) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        blankCard
                        ForEach(ScriptTemplate.all) { t in
                            templateCard(t)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("New Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var blankCard: some View {
        Button {
            onPick(Script())
            dismiss()
        } label: {
            HStack(spacing: 14) {
                iconBadge("doc.badge.plus")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blank script").font(.headline).foregroundStyle(palette.textPrimary)
                    Text("Start from scratch").font(.caption).foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(palette.textFaint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func templateCard(_ t: ScriptTemplate) -> some View {
        Button {
            onPick(Script(title: t.title, body: t.body))
            dismiss()
        } label: {
            HStack(spacing: 14) {
                iconBadge(t.icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(.headline).foregroundStyle(palette.textPrimary)
                    Text(t.blurb).font(.caption).foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(palette.textFaint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func iconBadge(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.black)
            .frame(width: 42, height: 42)
            .background(tm.accentGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
