import SwiftUI
import AVFoundation
import MediaPlayer

/// Detects hardware volume-button presses and reports them, without changing the
/// actual volume or showing the system volume HUD. Used for hands-free play/pause.
///
/// Note: this needs a real device — the Simulator has no volume buttons.
@MainActor
final class VolumeButtonObserver: NSObject, ObservableObject {
    var onPress: () -> Void = {}

    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private var baseline: Float = 0.5
    private var hiddenVolumeView: MPVolumeView?
    private var active = false
    private var ignoreNext = false
    private var ownsSession = false
    private var armed = false   // ignore the settling changes that happen right after start

    /// - Parameter configuresSession: when true (screen mode) we own a quiet playback
    ///   session. In camera mode pass false so the capture session keeps owning audio
    ///   and recording isn't disrupted — we just observe the volume passively.
    func start(configuresSession: Bool = true) {
        guard !active else { return }
        active = true

        ownsSession = configuresSession
        if configuresSession {
            try? session.setCategory(.playback, options: [.mixWithOthers])
            try? session.setActive(true)
        }
        baseline = session.outputVolume

        // An off-screen MPVolumeView suppresses the on-screen volume HUD.
        let v = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
        v.alpha = 0.0001
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.addSubview(v)
        }
        hiddenVolumeView = v

        // Activating the session / adding the volume view can momentarily change the
        // reported volume; ignore those so we don't auto-trigger on open. Only real
        // button presses after this settling window count.
        armed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.baseline = self?.session.outputVolume ?? 0.5
            self?.armed = true
        }

        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.handleChange() }
        }
    }

    func stop() {
        guard active else { return }
        active = false
        observation?.invalidate()
        observation = nil
        hiddenVolumeView?.removeFromSuperview()
        hiddenVolumeView = nil
        if ownsSession {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func handleChange() {
        if !armed { return }
        if ignoreNext { ignoreNext = false; return }
        onPress()
        // Restore the volume to baseline so repeated presses keep working and the
        // user's real volume is untouched.
        ignoreNext = true
        setSystemVolume(baseline)
    }

    private func setSystemVolume(_ value: Float) {
        guard let slider = hiddenVolumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            slider.value = value
        }
    }
}
