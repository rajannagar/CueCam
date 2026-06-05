import Foundation
import SwiftUI

/// Local, on-device persistence. Scripts are saved as JSON in the app's Documents
/// directory — no server, no account, no network. This is what makes the app free to run.
@MainActor
final class ScriptStore: ObservableObject {
    @Published private(set) var scripts: [Script] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("scripts.json")
    }()

    /// Free users can keep this many scripts. Past this, the paywall appears.
    static let freeLimit = 3

    init() {
        load()
        if scripts.isEmpty {
            seedSample()
        }
    }

    func script(_ id: Script.ID) -> Script? {
        scripts.first { $0.id == id }
    }

    func add(_ script: Script) {
        scripts.insert(script, at: 0)
        save()
    }

    func update(_ script: Script) {
        guard let idx = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        var updated = script
        updated.updatedAt = .now
        scripts[idx] = updated
        scripts.sort { $0.updatedAt > $1.updatedAt }
        save()
    }

    func delete(at offsets: IndexSet) {
        scripts.remove(atOffsets: offsets)
        save()
    }

    func delete(_ id: Script.ID) {
        scripts.removeAll { $0.id == id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Script].self, from: data) else { return }
        scripts = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func seedSample() {
        let sample = Script(
            title: "Welcome to CueCam",
            body: """
            Hey there, and welcome to CueCam.

            Tap the camera button to record yourself while these words scroll right over the live camera. Your script stays on screen to read, but it never shows up in the video.

            Want to read on screen instead? Tap the text button. Either way: tap once to pause or resume, drag up or down to reposition, and open the sliders to pick a theme, font, speed, and text size.

            Turn on voice-follow and the words move as you speak. When you're ready, replace this text with your own. Break a leg.
            """
        )
        scripts = [sample]
        save()
    }
}
