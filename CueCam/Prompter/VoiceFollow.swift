import Foundation
import Speech
import AVFoundation

/// On-device speech recognition that reports how far through the script the speaker
/// has read, so the prompter can scroll to match their pace. Free to run - no network.
@MainActor
final class VoiceFollow: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var authorized = false
    @Published var progress: Double = 0
    @Published var errorText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Lowercased words of the script, used to match spoken words to a position.
    private var scriptWords: [String] = []
    private var matchedIndex = 0
    private var spokenConsumed = 0

    /// True while the caller wants us listening. Recognition tasks end on their
    /// own (after long speech or silence), so we restart as long as this is set;
    /// otherwise a long read would silently stall mid-script.
    private var wantListening = false
    private var restartTask: Task<Void, Never>?
    private var lastStartDate = Date.distantPast
    private var rapidRestarts = 0

    /// Feeding the script's own vocabulary to the recognizer makes it much more
    /// likely to hear those exact words. Apple caps the useful size, so keep it
    /// to the first 100 unique words.
    private var contextWords: [String] = []

    /// - Parameter startProgress: where the reader already is (0...1). Seeding
    ///   the match cursor here is what keeps voice-follow working after a
    ///   pause, a drag, or a resume mid-script; starting from zero would leave
    ///   it waiting forever for words the reader said minutes ago.
    func prepare(script: String, startProgress: Double = 0) {
        scriptWords = script
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        var unique: [String] = []
        var seen = Set<String>()
        for w in scriptWords where !seen.contains(w) {
            seen.insert(w)
            unique.append(w)
            if unique.count >= 100 { break }
        }
        contextWords = unique
        spokenConsumed = 0
        reseed(to: startProgress)
    }

    /// Jump the match cursor to a scroll position (0...1), e.g. after the
    /// reader drags the text while voice-follow is running.
    func reseed(to startProgress: Double) {
        guard !scriptWords.isEmpty else { matchedIndex = 0; progress = 0; return }
        let clamped = min(1, max(0, startProgress))
        matchedIndex = min(scriptWords.count, Int(Double(scriptWords.count) * clamped))
        progress = Double(matchedIndex) / Double(scriptWords.count)
    }

    func requestAuthorization() async {
        let speechOK = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micOK = await AVAudioApplication.requestRecordPermissionStandalone()
        authorized = speechOK && micOK
        if !authorized {
            errorText = "Enable Microphone and Speech Recognition in Settings to use voice-follow."
        }
    }

    func start() {
        wantListening = true
        beginListening()
    }

    private func beginListening() {
        guard authorized, !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorText = "Speech recognition isn't available right now."
            wantListening = false
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        request.contextualStrings = contextWords
        self.request = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorText = "Couldn't start audio. Close other audio apps and try again."
            return
        }

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorText = "Couldn't start the microphone."
            return
        }

        isListening = true
        lastStartDate = Date()
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.updateProgress(from: result.bestTranscription.formattedString)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in self.handleSessionEnd() }
            }
        }
    }

    func stop() {
        wantListening = false
        restartTask?.cancel()
        restartTask = nil
        teardown()
    }

    /// The recognition task ended on its own. Tear down, and if the reader still
    /// wants voice-follow, spin the recognizer back up. Progress is preserved:
    /// `matchedIndex` carries across restarts and `updateProgress` already
    /// resyncs when a fresh transcript starts from zero.
    private func handleSessionEnd() {
        teardown()
        guard wantListening else { return }

        // If sessions keep dying within seconds, something is actually wrong
        // (recognizer busy, mic contention). Give up instead of looping.
        if Date().timeIntervalSince(lastStartDate) < 2 {
            rapidRestarts += 1
        } else {
            rapidRestarts = 0
        }
        if rapidRestarts >= 5 {
            wantListening = false
            errorText = "Voice-follow stopped. Tap play to start it again."
            return
        }

        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, self.wantListening, !Task.isCancelled else { return }
            self.beginListening()
        }
    }

    private func teardown() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Advance a matching cursor through the script as recognized words arrive.
    /// Tolerant of small mismatches so a stumble doesn't desync the scroll.
    private func updateProgress(from transcript: String) {
        let spoken = transcript
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !scriptWords.isEmpty else { return }

        // If the transcript shrank (recognizer restarted), resync from the beginning.
        if spoken.count < spokenConsumed { spokenConsumed = 0 }

        // Process every newly recognized word once, advancing the cursor through the
        // script. Scanning a small look-ahead window tolerates stumbles and filler
        // words, and consuming all new words (not just the last) keeps it in step.
        while spokenConsumed < spoken.count {
            let word = spoken[spokenConsumed]
            let window = min(matchedIndex + 8, scriptWords.count)
            if matchedIndex < window {
                for i in matchedIndex..<window where matches(scriptWords[i], word) {
                    matchedIndex = i + 1
                    break
                }
            }
            spokenConsumed += 1
        }
        progress = Double(matchedIndex) / Double(scriptWords.count)
    }

    /// Exact match, or a shared 4-letter stem on longer words so "recording"
    /// still matches "record" and small misrecognitions don't stall the scroll.
    private func matches(_ scriptWord: String, _ spokenWord: String) -> Bool {
        if scriptWord == spokenWord { return true }
        if scriptWord.count >= 5, spokenWord.count >= 5,
           scriptWord.prefix(4) == spokenWord.prefix(4) { return true }
        return false
    }
}

extension AVAudioApplication {
    static func requestRecordPermissionStandalone() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }
}
