import SwiftUI

/// The heart of the app: a smooth, controllable auto-scrolling teleprompter.
/// Everything here is local and frame-driven — no dependencies, no network.
///
/// Premium details that make it feel Apple-grade:
///  • Controls fade away while you read, then return on a tap (immersive).
///  • A 3-2-1 countdown gives you time to settle before the words move.
///  • A hairline progress bar shows how far you are through the script.
///  • Every interaction is spring-animated and lightly haptic.
struct TeleprompterView: View {
    let script: Script

    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    // Playback
    @State private var offset: CGFloat = 0
    @State private var isPlaying = false
    @State private var finished = false
    @State private var countdown: Int? = nil

    // Settings (persisted between sessions)
    @AppStorage("tp.speed") private var speed: Double = 60       // points per second
    @AppStorage("tp.fontSize") private var fontSize: Double = 46
    @AppStorage("tp.mirror") private var mirror: Bool = false
    @AppStorage("tp.countdown") private var countdownEnabled: Bool = true

    // Layout / interaction
    @State private var contentHeight: CGFloat = 0
    @State private var containerSize: CGSize = .zero
    @State private var dragBase: CGFloat? = nil
    @State private var controlsVisible = true
    @State private var hideWork: DispatchWorkItem?
    @State private var countdownTask: Task<Void, Never>?
    @State private var showPaywall = false

    private let focalFraction: CGFloat = 0.40
    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            scrollingText
            focalGuides
            vignette

            progressBar
            topBar
            controls

            if let countdown { countdownOverlay(countdown) }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onReceive(tick) { _ in advance() }
        .onAppear { resetToStart() }
        .onDisappear { countdownTask?.cancel(); hideWork?.cancel() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: - Scrolling text

    private var scrollingText: some View {
        GeometryReader { geo in
            Text(script.body)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(fontSize * 0.32)
                .multilineTextAlignment(.center)
                .frame(width: geo.size.width - 48, alignment: .top)
                .padding(.horizontal, 24)
                .background(heightReader)
                .offset(y: offset)
                .scaleEffect(x: mirror ? -1 : 1, y: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .onAppear { containerSize = geo.size }
                .onChange(of: geo.size) { _, newValue in containerSize = newValue }
                .gesture(dragGesture)
                .onTapGesture { handleTap() }
        }
    }

    private var heightReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
        }
        .onPreferenceChange(HeightKey.self) { contentHeight = $0 }
    }

    // MARK: - Overlays

    private var focalGuides: some View {
        GeometryReader { geo in
            let y = geo.size.height * focalFraction
            ZStack {
                Triangle()
                    .fill(Theme.accent)
                    .frame(width: 15, height: 20)
                    .rotationEffect(.degrees(90))
                    .position(x: 16, y: y)
                Triangle()
                    .fill(Theme.accent)
                    .frame(width: 15, height: 20)
                    .rotationEffect(.degrees(-90))
                    .position(x: geo.size.width - 16, y: y)
                LinearGradient(
                    colors: [Theme.accent.opacity(0), Theme.accent.opacity(0.10), Theme.accent.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: fontSize * 1.7)
                .position(x: geo.size.width / 2, y: y)
            }
            .opacity(controlsVisible ? 1 : 0.5)
        }
        .allowsHitTesting(false)
    }

    private var vignette: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
            Spacer()
            LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 200)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule().fill(Theme.accentGradient)
                    .frame(width: max(0, geo.size.width * progress))
            }
            .frame(height: 3)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 6)
            .padding(.horizontal, 20)
        }
        .allowsHitTesting(false)
        .opacity(contentHeight > containerSize.height ? 1 : 0)
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 12) {
                circleButton("xmark") { dismiss() }
                Spacer()
                Text(script.title.isEmpty ? "Untitled" : script.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer()
                circleButton(mirror ? "rectangle.righthalf.filled" : "rectangle.lefthalf.filled") {
                    toggleMirror()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            Spacer()
        }
        .opacity(controlsVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: controlsVisible)
    }

    private var controls: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                HStack(spacing: 24) {
                    softButton("gobackward") { resetToStart() }
                    playButton
                    speedReadout
                }

                sliderRow(icon: "hare.fill", value: $speed, range: 12...220) {
                    "\(Int(speed)) pt/s"
                }
                sliderRow(icon: "textformat.size", value: $fontSize, range: 28...96) {
                    "\(Int(fontSize)) pt"
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
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
                Image(systemName: finished ? "arrow.counterclockwise" : (isPlaying ? "pause.fill" : "play.fill"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: 72, height: 72)
            .shadow(color: Theme.accent.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(PressStyle())
    }

    private var speedReadout: some View {
        VStack(spacing: 2) {
            Text("\(Int(speed))")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text("pt/s")
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
        }
        .frame(width: 56, height: 56)
        .background(.white.opacity(0.06), in: Circle())
    }

    private func countdownOverlay(_ n: Int) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            Text("\(n)")
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accentGradient)
                .id(n)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Reusable controls

    private func circleButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(PressStyle())
    }

    private func softButton(_ name: String, filled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.white.opacity(filled ? 0.08 : 0), in: Circle())
        }
        .buttonStyle(PressStyle())
    }

    private func sliderRow(icon: String, value: Binding<Double>, range: ClosedRange<Double>, label: () -> String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24)
            Slider(value: value, in: range)
                .tint(Theme.accent)
            Text(label())
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 56, alignment: .trailing)
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragBase == nil { dragBase = offset; isPlaying = false; cancelCountdown(); showControls() }
                offset = (dragBase ?? offset) + value.translation.height
            }
            .onEnded { _ in
                dragBase = nil
                finished = false
            }
    }

    private func handleTap() {
        if controlsVisible {
            togglePlay()
        } else {
            showControls()
        }
    }

    // MARK: - Playback logic

    private var progress: CGFloat {
        let start = startOffset
        let end = endOffset
        guard start > end else { return 0 }
        return min(1, max(0, (start - offset) / (start - end)))
    }

    private var startOffset: CGFloat { containerSize.height * focalFraction }
    private var endOffset: CGFloat { -(contentHeight - containerSize.height * (1 - focalFraction)) }

    private func advance() {
        guard isPlaying, !finished, countdown == nil else { return }
        offset -= CGFloat(speed) / 60.0
        if offset <= endOffset {
            offset = endOffset
            isPlaying = false
            finished = true
            showControls()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func togglePlay() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if finished {
            resetToStart()
            beginPlayback()
            return
        }
        if isPlaying {
            isPlaying = false
            cancelCountdown()
            showControls()
        } else {
            beginPlayback()
        }
    }

    private func beginPlayback() {
        let nearStart = abs(offset - startOffset) < 4
        if countdownEnabled && nearStart {
            startCountdown()
        } else {
            isPlaying = true
            scheduleHide()
        }
    }

    private func startCountdown() {
        cancelCountdown()
        countdownTask = Task { @MainActor in
            for n in stride(from: 3, through: 1, by: -1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { countdown = n }
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                try? await Task.sleep(nanoseconds: 700_000_000)
                if Task.isCancelled { countdown = nil; return }
            }
            withAnimation(.easeOut(duration: 0.2)) { countdown = nil }
            isPlaying = true
            scheduleHide()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        if countdown != nil { withAnimation { countdown = nil } }
    }

    private func resetToStart() {
        finished = false
        isPlaying = false
        cancelCountdown()
        showControls()
        withAnimation(.easeOut(duration: 0.35)) { offset = startOffset }
    }

    private func toggleMirror() {
        guard purchases.isPro else {
            isPlaying = false
            showPaywall = true
            return
        }
        withAnimation(.spring) { mirror.toggle() }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    // MARK: - Controls auto-hide

    private func showControls() {
        withAnimation { controlsVisible = true }
        scheduleHide()
    }

    private func scheduleHide() {
        hideWork?.cancel()
        guard isPlaying else { return }
        let work = DispatchWorkItem {
            withAnimation { controlsVisible = false }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}

// MARK: - Button press style

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Helpers

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
