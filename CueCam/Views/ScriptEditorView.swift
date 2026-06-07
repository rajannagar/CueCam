import SwiftUI

struct ScriptEditorView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var store: ScriptStore
    @EnvironmentObject private var tm: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Script
    @FocusState private var bodyFocused: Bool
    private let isNew: Bool

    init(script: Script) {
        _draft = State(initialValue: script)
        isNew = script.body.isEmpty && script.title.isEmpty
    }

    private var trimmedBody: String {
        draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var charCount: Int { draft.body.count }
    private var readTime: String {
        let secs = max(1, Int((Double(draft.wordCount) / 130.0) * 60.0))
        return secs >= 60 ? "\(secs / 60)m \(secs % 60)s" : "\(secs)s"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 14) {
                    titleField
                    editorCard
                    statsBar
                }
                .padding(18)
            }
            .navigationTitle(isNew ? "New Script" : "Edit Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedBody.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button { paste() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                    Spacer()
                    Button("Done") { bodyFocused = false }.fontWeight(.semibold)
                }
            }
        }
    }

    private var titleField: some View {
        TextField("", text: $draft.title, prompt: Text("Title").foregroundColor(palette.textFaint))
            .font(.title3.weight(.semibold))
            .foregroundStyle(palette.textPrimary)
            .padding(16)
            .cardStyle()
    }

    private var editorCard: some View {
        VStack(spacing: 0) {
            // Toolbar row
            HStack(spacing: 10) {
                toolButton("doc.on.clipboard", "Paste") { paste() }
                if !trimmedBody.isEmpty {
                    toolButton("xmark.circle", "Clear") { draft.body = "" }
                }
                Spacer()
                Text("Script")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textFaint)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider().overlay(palette.cardStroke)

            ZStack(alignment: .topLeading) {
                if draft.body.isEmpty {
                    Text("Write or paste your script here.\n\nTip: a blank line makes a clean break between paragraphs as it scrolls.")
                        .font(.system(size: 17))
                        .foregroundStyle(palette.textFaint)
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                }
                TextEditor(text: $draft.body)
                    .font(.system(size: 17))
                    .foregroundStyle(palette.textPrimary)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .focused($bodyFocused)
            }
        }
        .cardStyle()
    }

    private var statsBar: some View {
        HStack(spacing: 18) {
            stat("\(draft.wordCount)", "words")
            stat("\(charCount)", "chars")
            stat("~\(readTime)", "read")
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .cardStyle()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(palette.textPrimary)
            Text(label).font(.caption).foregroundStyle(palette.textFaint)
        }
    }

    private func toolButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption.weight(.medium))
            }
            .foregroundStyle(tm.accent)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(tm.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func paste() {
        if let s = UIPasteboard.general.string {
            if draft.body.isEmpty { draft.body = s }
            else { draft.body += (draft.body.hasSuffix("\n") ? "" : "\n") + s }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func save() {
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.title = String(trimmedBody.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if store.script(draft.id) == nil {
            store.add(draft)
        } else {
            store.update(draft)
        }
        dismiss()
    }
}
