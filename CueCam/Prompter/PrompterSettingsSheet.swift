import SwiftUI

/// The in-prompter quick-settings sheet (the "sliders" button). Wraps the shared
/// PrompterPreferences so the same controls live here and in the main Settings.
struct PrompterSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    PrompterPreferences().padding(18)
                }
            }
            .navigationTitle("Prompter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
