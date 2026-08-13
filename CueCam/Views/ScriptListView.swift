import SwiftUI
import StoreKit

struct ScriptListView: View {
    @Environment(\.palette) private var palette
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var store: ScriptStore
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var tm: ThemeManager

    /// Good sessions so far (a finished read or a saved recording), counted by
    /// the prompter views. Used to time the rating ask.
    @AppStorage("tp.reviewMoments") private var reviewMoments = 0
    @AppStorage("tp.reviewAskedAt") private var reviewAskedAt = 0

    @State private var editingScript: Script?
    @State private var playingScript: Script?
    @State private var filmingScript: Script?
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showTemplates = false
    @State private var shareItems: [Any]?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if store.scripts.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .principal) {
                    Text("CueCam")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newScript()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("New script")
                }
            }
            .sheet(item: $editingScript) { script in
                ScriptEditorView(script: script)
            }
            .fullScreenCover(item: $playingScript, onDismiss: maybeRequestReview) { script in
                TeleprompterView(script: script)
            }
            .fullScreenCover(item: $filmingScript, onDismiss: maybeRequestReview) { script in
                CameraTeleprompterView(script: script)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showTemplates) {
                TemplatePickerView { editingScript = $0 }
            }
            .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
                if let items = shareItems { ShareSheet(items: items) }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                HStack {
                    Text("Scripts")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                }
                .padding(.top, 4)
                if !purchases.isPro {
                    freeBanner
                }
                ForEach(store.scripts) { script in
                    ScriptCard(
                        script: script,
                        onFilm: { filmingScript = script },
                        onPlay: { playingScript = script },
                        onEdit: { editingScript = script }
                    )
                    .contextMenu {
                        Button { filmingScript = script } label: {
                            Label("Record with camera", systemImage: "camera")
                        }
                        Button { playingScript = script } label: {
                            Label("Read on screen", systemImage: "text.alignleft")
                        }
                        Button { editingScript = script } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button { shareAsPDF(script) } label: {
                            Label("Share as PDF", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            store.delete(script.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    private var freeBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(tm.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free plan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text("\(store.scripts.count)/\(ScriptStore.freeLimit) scripts used · Unlock unlimited + mirror mode")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.textFaint)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 54))
                .foregroundStyle(tm.accentGradient)
            Text("No scripts yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text("Tap + to write or paste your first script.")
                .font(.callout)
                .foregroundStyle(palette.textSecondary)
            Button {
                newScript()
            } label: {
                Text("New Script")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(tm.accentGradient, in: Capsule())
                    .foregroundStyle(.black)
            }
            .padding(.top, 4)
        }
        .padding()
    }

    private func newScript() {
        if !purchases.isPro && store.scripts.count >= ScriptStore.freeLimit {
            showPaywall = true
            return
        }
        showTemplates = true
    }

    private func shareAsPDF(_ script: Script) {
        if let url = ScriptPDF.make(from: script) { shareItems = [url] }
    }

    /// Ask for a rating only back on the home screen after a good session,
    /// never mid-task: once after the second good moment, once more after the
    /// twelfth. The system also caps how often the prompt actually shows.
    private func maybeRequestReview() {
        let shouldAsk = (reviewMoments >= 2 && reviewAskedAt == 0)
            || (reviewMoments >= 12 && reviewAskedAt < 12)
        guard shouldAsk else { return }
        reviewAskedAt = reviewMoments
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { requestReview() }
    }
}

private struct ScriptCard: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var tm: ThemeManager
    let script: Script
    let onFilm: () -> Void
    let onPlay: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(script.title.isEmpty ? "Untitled" : script.title)
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Text(metaLine)
                        .font(.caption)
                        .foregroundStyle(palette.textFaint)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button(action: onPlay) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(palette.textPrimary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Read on screen")
                    Button(action: onFilm) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(tm.accentGradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Record with camera")
                }
            }

            Text(script.preview)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .onTapGesture(perform: onEdit)
    }

    private var metaLine: String {
        let secs = script.estimatedReadSeconds
        let time = secs >= 60 ? "\(secs / 60)m \(secs % 60)s" : "\(secs)s"
        return "\(script.wordCount) words · ~\(time)"
    }
}
