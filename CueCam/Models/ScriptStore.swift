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
            Hey there, and welcome to CueCam, your pocket teleprompter.

            Here's the idea: you read, the words scroll, and you never have to memorize a thing. Let me show you around while you read this.

            See the speed and text-size sliders below? Slide them anytime to find a pace that feels natural. Tap once anywhere to pause, tap again to keep going, and drag up or down to jump to any line.

            There are two ways to use a script. Tap the camera button to record yourself while the words glide over the live video. Your script stays on screen, but it never shows up in the recording. Or tap the text button to simply read on screen.

            Want to make it yours? Open the sliders icon, or head to Settings, to choose from nine themes, pick a font, and set your text color.

            A few favorites worth trying: turn on Voice-Follow and the script moves as you speak. Switch on Karaoke to keep the line you're reading bright while the rest dims. And use the volume buttons to play, pause, or record completely hands-free.

            That's the tour. When you're ready, tap Edit to replace this with your own script: a video intro, a speech, a sales pitch, anything. Break a leg.
            """
        )
        scripts = [sample]
        save()
    }
}
