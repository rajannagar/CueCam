import Foundation
@preconcurrency import AVFoundation
import Photos
import UIKit

/// Drives the camera prompter: live preview, front/back switching (even mid-recording),
/// and pausable recording via AVAssetWriter. The on-screen script is an overlay only —
/// it is never part of the recorded video.
@MainActor
final class CameraController: NSObject, ObservableObject {
    enum Status { case idle, configuring, ready, denied, failed }

    @Published var status: Status = .idle
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var position: AVCaptureDevice.Position = .front
    @Published var elapsed: TimeInterval = 0
    @Published var lastSavedOK: Bool? = nil
    @Published var message: String?
    @Published var lastRecordingURL: URL?

    // These AVCapture objects are only ever touched on sessionQueue/dataQueue, so they
    // are marked nonisolated(unsafe) to opt out of main-actor isolation safely.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let audioOutput = AVCaptureAudioDataOutput()
    nonisolated private let sessionQueue = DispatchQueue(label: "cuecam.session")
    nonisolated private let dataQueue = DispatchQueue(label: "cuecam.data")
    nonisolated private let recorder = PausableRecorder()
    nonisolated(unsafe) private var forwarder: CaptureForwarder?
    nonisolated(unsafe) private var videoInput: AVCaptureDeviceInput?
    private var timer: Timer?

    // MARK: - Setup

    func configure() async {
        let camOK = await Self.granted(for: .video)
        let micOK = await Self.granted(for: .audio)
        guard camOK && micOK else {
            status = .denied
            message = "Enable Camera and Microphone access in Settings to record."
            return
        }
        status = .configuring
        let forwarder = CaptureForwarder(recorder: recorder, videoOutput: videoOutput)
        self.forwarder = forwarder
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                self?.buildSession(forwarder: forwarder)
                cont.resume()
            }
        }
    }

    private static func granted(for type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: type)
        default: return false
        }
    }

    private nonisolated func buildSession(forwarder: CaptureForwarder) {
        session.beginConfiguration()
        session.sessionPreset = .high
        // We manage the audio session ourselves via AVAudioSession; let the capture
        // session configure it for recording.
        session.automaticallyConfiguresApplicationAudioSession = true

        if let device = Self.camera(for: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            Task { @MainActor in self.videoInput = input }
        }
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(forwarder, queue: dataQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        audioOutput.setSampleBufferDelegate(forwarder, queue: dataQueue)
        if session.canAddOutput(audioOutput) { session.addOutput(audioOutput) }

        configureVideoConnection(position: .front)

        session.commitConfiguration()
        session.startRunning()
        Task { @MainActor in self.status = .ready }
    }

    private nonisolated func configureVideoConnection(position: AVCaptureDevice.Position) {
        guard let c = videoOutput.connection(with: .video) else { return }
        if #available(iOS 17.0, *), c.isVideoRotationAngleSupported(90) {
            c.videoRotationAngle = 90    // portrait
        }
        if c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = (position == .front)
        }
    }

    private nonisolated static func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video)
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - Switch camera (works while recording)

    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = position == .front ? .back : .front
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if let current = self.videoInput { self.session.removeInput(current) }
            if let device = Self.camera(for: newPosition),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                Task { @MainActor in self.videoInput = input; self.position = newPosition }
            }
            self.configureVideoConnection(position: newPosition)
            self.session.commitConfiguration()
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard status == .ready, !isRecording else { return }
        let videoSettings = videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
        let audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
        recorder.start(videoSettings: videoSettings, audioSettings: audioSettings)
        isRecording = true
        isPaused = false
        lastSavedOK = nil
        elapsed = 0
        startTimer()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func stopRecording() {
        guard isRecording else { return }
        timer?.invalidate(); timer = nil
        isRecording = false
        isPaused = false
        recorder.finish { [weak self] url in
            Task { @MainActor in await self?.handleFinished(url) }
        }
    }

    /// Pause/resume the recording itself (paused time is cut from the final video).
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        recorder.pause()
        timer?.invalidate(); timer = nil
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        isPaused = false
        recorder.resume()
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed += 0.1 }
        }
    }

    private func handleFinished(_ url: URL?) async {
        guard let url else {
            message = "Recording failed. Please try again."
            lastSavedOK = false
            return
        }
        let ok = await Self.saveToPhotos(url)
        lastSavedOK = ok
        message = ok ? "Saved to your photos." : "Couldn't save to Photos. Check permissions in Settings."
        lastRecordingURL = url
    }

    private static func saveToPhotos(_ url: URL) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { authStatus in
                guard authStatus == .authorized || authStatus == .limited else {
                    cont.resume(returning: false); return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
                } completionHandler: { success, _ in
                    cont.resume(returning: success)
                }
            }
        }
    }
}

/// Forwards capture sample buffers to the recorder, tagging video vs audio.
final class CaptureForwarder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let recorder: PausableRecorder
    private let videoOutput: AVCaptureVideoDataOutput

    init(recorder: PausableRecorder, videoOutput: AVCaptureVideoDataOutput) {
        self.recorder = recorder
        self.videoOutput = videoOutput
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        recorder.append(sampleBuffer, isVideo: output === videoOutput)
    }
}
