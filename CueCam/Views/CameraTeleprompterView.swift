import SwiftUI

/// Camera mode: the script scrolls over the live camera while you record yourself.
/// The text is an on-screen overlay only - it is never burned into the video.
struct CameraTeleprompterView: View {
    @Environment(\.palette) private var palette
    let script: Script

    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var tm: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var engine = PrompterEngine()
    @StateObject private var camera = CameraController()
    @StateObject private var voice = VoiceFollow()

    @AppStorage("tp.speed") private var speed: Double = 60
    // Camera mode keeps its own text size: over live video the text wants to be
    // smaller than on a blank reading screen.
    @AppStorage("tp.fontSizeCamera") private var fontSize: Double = 44
    @AppStorage("tp.mirror") private var mirror = false
    @AppStorage("tp.countdown") private var countdownEnabled = true
    @AppStorage("tp.font") private var fontRaw = PrompterFont.serif.rawValue
    @AppStorage("tp.bold") private var bold = false
    @AppStorage("tp.textColorHex") private var textColorHex = ""
    @AppStorage("tp.focal") private var focal: Double = 0.40
    @AppStorage("tp.voiceFollow") private var voiceFollow = false
    @AppStorage("tp.karaoke") private var karaoke = false
    @AppStorage("tp.aspect") private var aspectRaw = AspectGuide.off.rawValue
    @AppStorage("tp.volumeControl") private var volumeControl = false

    @StateObject private var volume = VolumeButtonObserver()

    @State private var controlsVisible = true
    @State private var hideWork: DispatchWorkItem?
    @State private var showSettings = false
    @State private var dragBase: CGFloat?
    @State private var recordArmed = false
    @State private var showToast = false
    @State private var showShare = false

    private var theme: PrompterTheme { tm.selected }
    private var font: PrompterFont {
        let f = PrompterFont(rawValue: fontRaw) ?? .serif
        return (f.isFree || purchases.isPro) ? f : .serif
    }
    private var usingVoice: Bool { voiceFollow && purchases.isPro }
    private var usingVolume: Bool { volumeControl && purchases.isPro }
    /// Below iOS 17.2 there is no capture-event API, so volume-button control
    /// falls back to the KVO observer.
    private var needsLegacyVolumeObserver: Bool {
        if #available(iOS 17.2, *) { return false }
        return true
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.status == .ready {
                CameraPreview(controller: camera).ignoresSafeArea()
            }

            // Hardware volume buttons act as a record button while the capture
            // session runs (supported API, no volume change, no HUD).
            if usingVolume, #available(iOS 17.2, *) {
                CaptureEventListener { tapRecord() }
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }

            // Text always white-ish over video for legibility, regardless of theme bg.
            PrompterCanvas(engine: engine, text: script.body, fontSize: fontSize,
                           font: font, textColor: cameraTextColor,
                           mirror: mirror && purchases.isPro, bold: bold,
                           karaoke: karaoke && purchases.isPro, dimText: 0.96)

            AspectGuideOverlay(guide: AspectGuide(rawValue: aspectRaw) ?? .off)
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .onTapGesture { handleTap() }

            topBar
            bottomControls

            if camera.status == .denied { permissionOverlay }
            if showToast, let msg = camera.message { toast(msg) }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .keepsScreenAwake()
        .task {
            engine.startLink()
            engine.speed = speed
            engine.focalFraction = CGFloat(focal)
            engine.voiceFollow = usingVoice
            engine.reset()
            await camera.configure()
            if usingVolume && needsLegacyVolumeObserver {
                volume.onPress = { tapRecord() }
                volume.start(configuresSession: false)
            }
        }
        .onChange(of: focal) { _, v in engine.focalFraction = CGFloat(v); engine.reset() }
        .onChange(of: volumeControl) { _, _ in
            if usingVolume && needsLegacyVolumeObserver {
                volume.onPress = { tapRecord() }
                volume.start(configuresSession: false)
            } else {
                volume.stop()
            }
        }
        .onDisappear { engine.stopLink(); camera.stop(); voice.stop(); volume.stop() }
        .onChange(of: speed) { _, v in engine.speed = v }
        .onChange(of: voiceFollow) { _, _ in engine.voiceFollow = usingVoice }
        .onChange(of: voice.progress) { _, p in engine.voiceProgress = p }
        .onChange(of: engine.isPlaying) { _, playing in
            if recordArmed && playing && !camera.isRecording {
                camera.toggleRecording()                 // start recording when the scroll begins
            }
            syncVoice(playing: playing)
            scheduleHide()
        }
        .onChange(of: engine.finished) { _, finished in
            if finished && camera.isRecording { camera.toggleRecording() }  // auto-stop & save at the end
        }
        .onChange(of: camera.lastSavedOK) { _, v in
            guard v != nil else { return }
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { showToast = false } }
        }
        .sheet(isPresented: $showSettings) { PrompterSettingsSheet() }
        .sheet(isPresented: $showShare) {
            if let url = camera.lastRecordingURL { ShareSheet(items: [url]) }
        }
    }

    private var cameraTextColor: Color {
        if purchases.isPro, !textColorHex.isEmpty, let c = Color(hex: textColorHex) { return c }
        return theme.cameraTextColor
    }

    // MARK: - Overlays

    private var topBar: some View {
        VStack {
            HStack(spacing: 12) {
                circleButton("xmark", label: "Close") {
                    // Freeze the prompter before the cover animates away, so the
                    // huge text layer is not mid-update during the transition.
                    engine.stopLink()
                    voice.stop()
                    dismiss()
                }
                Spacer()
                if camera.isRecording { recordingPill }
                Spacer()
                aspectButton
                if camera.lastRecordingURL != nil && !camera.isRecording {
                    circleButton("square.and.arrow.up", label: "Share last recording") { showShare = true }
                }
                circleButton("arrow.triangle.2.circlepath", label: "Switch camera") { camera.switchCamera() }
                    .disabled(camera.isRecording)
                    .opacity(camera.isRecording ? 0.35 : 1)
                circleButton("slider.horizontal.3", label: "Prompter settings") { engine.isPlaying = false; showSettings = true }
            }
            .padding(.horizontal, 16).padding(.top, 18)
            Spacer()
        }
        .opacity(controlsVisible || camera.isRecording ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
    }

    private var aspectButton: some View {
        let guide = AspectGuide(rawValue: aspectRaw) ?? .off
        return Button {
            aspectRaw = guide.next().rawValue
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            Text(guide.label)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(height: 40).padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Aspect ratio guide: \(guide.label)")
    }

    private var recordingPill: some View {
        HStack(spacing: 6) {
            Circle().fill(.red).frame(width: 8, height: 8)
            Text(timeString(camera.elapsed))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var bottomControls: some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 28) {
                    softButton("gobackward", label: "Restart from the top") { engine.reset() }
                    recordButton
                    scrollToggle
                }
                if !usingVoice {
                    sliderRow(icon: "hare.fill", value: $speed, range: 12...220) { "\(Int(speed))" }
                }
                sliderRow(icon: "textformat.size", value: $fontSize, range: 28...90) { "\(Int(fontSize))" }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 14).padding(.bottom, 14)
            .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        }
        .opacity(controlsVisible ? 1 : 0)
        .offset(y: controlsVisible ? 0 : 30)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: controlsVisible)
    }

    /// Big record button. Starts the scroll (with countdown) and recording together.
    private var recordButton: some View {
        Button { tapRecord() } label: {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                RoundedRectangle(cornerRadius: camera.isRecording ? 8 : 32, style: .continuous)
                    .fill(.red)
                    .frame(width: camera.isRecording ? 32 : 62, height: camera.isRecording ? 32 : 62)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: camera.isRecording)
            }
        }
        .buttonStyle(PressStyle())
        .disabled(camera.status != .ready)
        .opacity(camera.status == .ready ? 1 : 0.4)
        .accessibilityLabel(camera.isRecording ? "Stop recording" : "Start recording")
    }

    private var scrollToggle: some View {
        Button { engine.togglePlay(countdownEnabled: countdownEnabled && !camera.isRecording) } label: {
            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                .frame(width: 56, height: 56).background(.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(engine.isPlaying ? "Pause scrolling" : "Start scrolling")
    }

    private var permissionOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(tm.accentGradient)
                Text("Camera access needed")
                    .font(.title3.weight(.bold)).foregroundStyle(.white)
                Text(camera.message ?? "Enable Camera and Microphone in Settings.")
                    .font(.callout).foregroundStyle(palette.textSecondary).multilineTextAlignment(.center)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Text("Open Settings").font(.headline)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(tm.accentGradient, in: Capsule()).foregroundStyle(.black)
                }
                Button("Close") { dismiss() }.foregroundStyle(palette.textSecondary).padding(.top, 4)
            }
            .padding(32)
        }
    }

    private func toast(_ msg: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: camera.lastSavedOK == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(msg).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 180)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    // MARK: - Reusable bits

    private func sliderRow(icon: String, value: Binding<Double>, range: ClosedRange<Double>, label: () -> String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(.white.opacity(0.8)).frame(width: 24)
            Slider(value: value, in: range).tint(tm.accent)
            Text(label()).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.8)).frame(width: 40, alignment: .trailing)
        }
    }

    private func circleButton(_ name: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }

    private func softButton(_ name: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 56, height: 56).background(.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }

    // MARK: - Logic

    private func tapRecord() {
        if camera.isRecording {
            camera.toggleRecording()
            engine.isPlaying = false
            recordArmed = false
        } else {
            recordArmed = true
            if engine.finished { engine.reset() }
            engine.beginPlayback(countdownEnabled: countdownEnabled)
            // If scrolling won't auto-start (already mid-script), start recording now.
            if engine.isPlaying && !camera.isRecording { camera.toggleRecording() }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragBase == nil { dragBase = engine.offset; engine.markEngaged(); showControls() }
                engine.offset = (dragBase ?? engine.offset) + value.translation.height
            }
            .onEnded { _ in
                dragBase = nil
                engine.finished = false
                if usingVoice { voice.reseed(to: engine.textFraction) }
            }
    }

    private func handleTap() {
        withAnimation { controlsVisible.toggle() }
        if controlsVisible { scheduleHide() }
    }

    private func syncVoice(playing: Bool) {
        guard usingVoice else { return }
        if playing {
            Task {
                if !voice.authorized { await voice.requestAuthorization() }
                // Seed from the current scroll position: resuming mid-script
                // must not wait for words the reader said minutes ago.
                voice.prepare(script: script.body, startProgress: engine.textFraction)
                voice.start()
            }
        } else {
            voice.stop()
        }
    }

    private func showControls() {
        withAnimation { controlsVisible = true }
        scheduleHide()
    }

    private func scheduleHide() {
        hideWork?.cancel()
        guard engine.isPlaying else { return }
        let work = DispatchWorkItem { withAnimation { controlsVisible = false } }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: work)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
