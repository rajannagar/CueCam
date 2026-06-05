import Foundation
import AVFoundation
import Photos
import UIKit

/// Wraps an AVCaptureSession for the camera prompter: live preview, front/back
/// switching, and recording to the photo library. The on-screen script is NOT part
/// of the recording — it's an overlay you read, so your video stays clean.
@MainActor
final class CameraController: NSObject, ObservableObject {
    enum Status { case idle, configuring, ready, denied, failed }

    @Published var status: Status = .idle
    @Published var isRecording = false
    @Published var position: AVCaptureDevice.Position = .front
    @Published var elapsed: TimeInterval = 0
    @Published var lastSavedOK: Bool? = nil
    @Published var message: String?

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "cuecam.session")
    private var videoInput: AVCaptureDeviceInput?
    private var timer: Timer?

    // MARK: - Permissions & setup

    func configure() async {
        let camOK = await Self.granted(for: .video)
        let micOK = await Self.granted(for: .audio)
        guard camOK && micOK else {
            status = .denied
            message = "Enable Camera and Microphone access in Settings to record."
            return
        }
        status = .configuring
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                self?.buildSession()
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

    private nonisolated func buildSession() {
        let session = self.session
        session.beginConfiguration()
        session.sessionPreset = .high

        // Camera input
        if let device = Self.camera(for: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            Task { @MainActor in self.videoInput = input }
        }
        // Mic input
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        session.commitConfiguration()
        session.startRunning()
        Task { @MainActor in self.status = .ready }
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

    // MARK: - Switching camera

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
            self.session.commitConfiguration()
        }
    }

    // MARK: - Recording

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard status == .ready, !movieOutput.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        if let connection = movieOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = (position == .front)
        }
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        lastSavedOK = nil
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed += 0.1 }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
        timer?.invalidate()
        timer = nil
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            guard error == nil else {
                self.message = "Recording failed. Please try again."
                self.lastSavedOK = false
                return
            }
            await self.save(outputFileURL)
        }
    }

    private func save(_ url: URL) async {
        let ok = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
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
        lastSavedOK = ok
        message = ok ? "Saved to your photos." : "Couldn't save to Photos. Check permissions in Settings."
        try? FileManager.default.removeItem(at: url)
    }
}
