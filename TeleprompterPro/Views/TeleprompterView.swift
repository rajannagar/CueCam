import SwiftUI

/// Screen mode: read the script on a full-screen, themed background.
struct TeleprompterView: View {
    let script: Script

    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var engine = PrompterEngine()
    @StateObject private var voice = VoiceFollow()

    @AppStorage("tp.speed") private var speed: Double = 60
    @AppStorage("tp.fontSize") private var fontSize: Double = 46
    @AppStorage("tp.mirror") private var mirror = false
    @AppStorage("tp.countdown") private var countdownEnabled = true
    @AppStorage("tp.theme") private var themeRaw = PrompterTheme.classic.rawValue
    @AppStorage("tp.font") private var fontRaw = PrompterFont.rounded.rawValue
    @AppStorage("tp.voiceFollow") private var voiceFollow = false

    @State private var controlsVisible = true
    @State private var hideWork: DispatchWorkItem?
    @State private var showSettings = false
    @State private var dragBase: CGFloat?

    private var theme: PrompterTheme { PrompterTheme(rawValue: themeRaw) ?? .classic }
    private var font: PrompterFont { PrompterFont(rawValue: fontRaw) ?? .rounded }
    private var usingVoice: Bool { voiceFollow && purchases.isPro }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            PrompterCanvas(engine: engine, text: script.body, fontSize: fontSize,
                           font: font, textColor: theme.textColor,
                           mirror: mirror && purchases.isPro)
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .onTapGesture { handleTap() }

            vignette
            progressBar
            topBar
            controls
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            engine.startLink()
            engine.speed = speed
            engine.voiceFollow = usingVoice
            engine.reset()
        }
        .onDisappear { engine.stopLink(); voice.stop() }
        .onChange(of: speed) { _, v in engine.speed = v }
        .onChange(of: voiceFollow) { _, _ in engine.voiceFollow = usingVoice }
        .onChange(of: voice.progress) { _, p in engine.voiceProgress = p }
        .onChange(of: engine.isPlaying) { _, playing in
            syncVoice(playing: playing)
            scheduleHide()
        }
        .sheet(isPresented: $showSettings) {
            PrompterSettingsSheet()
        }
    }

    // MARK: - Overlays

    private var vignette: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [theme.background, theme.background.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
            Spacer()
            LinearGradient(colors: [theme.background.opacity(0), theme.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 200)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.textColor.opacity(0.12))
                Capsule().fill(Theme.accentGradient)
                    .frame(width: max(0, geo.size.width * engine.progress))
            }
            .frame(height: 3)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 6).padding(.horizontal, 20)
        }
        .allowsHitTesting(false)
        .opacity(engine.contentHeight > engine.containerHeight ? 1 : 0)
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 12) {
                circleButton("xmark") { dismiss() }
                Spacer()
                if usingVoice {
                    Label("Voice", systemImage: "waveform")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(voice.isListening ? Theme.accent : Theme.textSecondary)
                }
                Spacer()
                circleButton("slider.horizontal.3") { engine.isPlaying = false; showSettings = true }
            }
            .padding(.horizontal, 16).padding(.top, 18)
            Spacer()
        }
        .opacity(controlsVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
    }

    private var controls: some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                HStack(spacing: 24) {
                    softButton("gobackward") { engine.reset() }
                    playButton
                    speedReadout
                }
                if !usingVoice {
                    sliderRow(icon: "hare.fill", value: $speed, range: 12...220) { "\(Int(speed)) pt/s" }
                }
                sliderRow(icon: "textformat.size", value: $fontSize, range: 28...96) { "\(Int(fontSize)) pt" }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 14).padding(.bottom, 14)
            .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        }
        .opacity(controlsVisible ? 1 : 0)
        .offset(y: controlsVisible ? 0 : 30)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: controlsVisible)
    }

    private var playButton: some View {
        Button { togglePlay() } label: {
            ZStack {
                Circle().fill(Theme.accentGradient)
                Image(systemName: engine.finished ? "arrow.counterclockwise" : (engine.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.system(size: 28, weight: .bold)).foregroundStyle(.black)
            }
            .frame(width: 72, height: 72)
            .shadow(color: Theme.accent.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(PressStyle())
    }

    private var speedReadout: some View {
        VStack(spacing: 2) {
            Image(systemName: usingVoice ? "waveform" : "speedometer")
                .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Text(usingVoice ? "voice" : "\(Int(speed))")
                .font(.caption2).foregroundStyle(Theme.textFaint)
        }
        .frame(width: 56, height: 56)
        .background(.white.opacity(0.06), in: Circle())
    }

    private func sliderRow(icon: String, value: Binding<Double>, range: ClosedRange<Double>, label: () -> String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.textSecondary).frame(width: 24)
            Slider(value: value, in: range).tint(Theme.accent)
            Text(label()).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary).frame(width: 56, alignment: .trailing)
        }
    }

    private func circleButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(PressStyle())
    }

    private func softButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 56, height: 56).background(.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - Interaction

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragBase == nil { dragBase = engine.offset; engine.isPlaying = false; engine.cancelCountdown(); showControls() }
                engine.offset = (dragBase ?? engine.offset) + value.translation.height
            }
            .onEnded { _ in dragBase = nil; engine.finished = false }
    }

    private func handleTap() {
        if controlsVisible { togglePlay() } else { showControls() }
    }

    private func togglePlay() {
        engine.togglePlay(countdownEnabled: countdownEnabled)
    }

    private func syncVoice(playing: Bool) {
        guard usingVoice else { return }
        if playing {
            Task {
                if !voice.authorized { await voice.requestAuthorization() }
                voice.prepare(script: script.body)
                voice.start()
            }
        } else {
            voice.stop()
        }
    }

    // MARK: - Auto-hide controls

    private func showControls() {
        withAnimation { controlsVisible = true }
        scheduleHide()
    }

    private func scheduleHide() {
        hideWork?.cancel()
        guard engine.isPlaying else { return }
        let work = DispatchWorkItem { withAnimation { controlsVisible = false } }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
