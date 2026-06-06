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

    func prepare(script: String) {
        scriptWords = script
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        matchedIndex = 0
        spokenConsumed = 0
        progress = 0
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
        guard authorized, !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorText = "Speech recognition isn't available right now."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
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
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.updateProgress(from: result.bestTranscription.formattedString)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in self.stop() }
            }
        }
    }

    func stop() {
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
            let window = min(matchedIndex + 6, scriptWords.count)
            if matchedIndex < window {
                for i in matchedIndex..<window where scriptWords[i] == word {
                    matchedIndex = i + 1
                    break
                }
            }
            spokenConsumed += 1
        }
        progress = Double(matchedIndex) / Double(scriptWords.count)
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
