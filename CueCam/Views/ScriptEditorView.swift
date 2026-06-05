import SwiftUI

struct ScriptEditorView: View {
    @EnvironmentObject private var store: ScriptStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Script
    @State private var playAfterSave = false
    private let isNew: Bool

    init(script: Script) {
        _draft = State(initialValue: script)
        isNew = script.body.isEmpty && script.title.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 14) {
                    TextField("Title", text: $draft.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(14)
                        .cardStyle()

                    ZStack(alignment: .topLeading) {
                        if draft.body.isEmpty {
                            Text("Write or paste your script here…")
                                .font(.body)
                                .foregroundStyle(Theme.textFaint)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 22)
                        }
                        TextEditor(text: $draft.body)
                            .font(.body)
                            .foregroundStyle(Theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                    }
                    .cardStyle()

                    HStack {
                        Text("\(draft.wordCount) words")
                            .font(.caption)
                            .foregroundStyle(Theme.textFaint)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                .padding(18)
            }
            .navigationTitle(isNew ? "New Script" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.title = String(draft.body.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if store.script(draft.id) == nil {
            store.add(draft)
        } else {
            store.update(draft)
        }
        dismiss()
    }
}
