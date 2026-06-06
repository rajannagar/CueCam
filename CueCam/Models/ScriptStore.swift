import Foundation
import SwiftUI

/// Local, on-device persistence. Scripts are saved as JSON in the app's Documents
/// directory - no server, no account, no network. This is what makes the app free to run.
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
            Welcome to CueCam, your pocket teleprompter.

            Read your script on screen, or record yourself while it scrolls over the live camera. Make it yours with themes, fonts, and voice-follow.

            Tap Edit to add your own script, and you're ready to go.
            """
        )
        scripts = [sample]
        save()
    }
}
