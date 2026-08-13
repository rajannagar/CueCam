import SwiftUI
import QuartzCore

/// Single source of truth for scroll position and playback, shared by both the
/// screen prompter and the camera prompter. Driven by a CADisplayLink for buttery
/// 120Hz-capable motion.
/// Holds only the scroll offset, which changes every frame. Isolating it in its own
/// observable object means only the moving text re-renders at 120Hz - not the whole
/// prompter UI (controls, materials, bars). This is what keeps scrolling buttery.
@MainActor
final class ScrollModel: ObservableObject {
    @Published var offset: CGFloat = 0
}

@MainActor
final class PrompterEngine: NSObject, ObservableObject {
    /// Per-frame scroll position lives here so high-frequency updates stay isolated.
    let scroll = ScrollModel()
    var offset: CGFloat {
        get { scroll.offset }
        set { scroll.offset = newValue }
    }

    @Published var isPlaying = false
    @Published var finished = false
    @Published var countdown: Int? = nil

    /// Layout, set by the view.
    var contentHeight: CGFloat = 0
    var containerHeight: CGFloat = 0 { didSet { pinToStartIfIdle() } }
    /// Where the reading line sits, as a fraction of screen height (user-adjustable).
    var focalFraction: CGFloat = 0.40

    /// True once the user has started playback or manually moved the text. Until then,
    /// the first line stays pinned to the start so play always begins at the top.
    private var hasStarted = false

    /// Config, synced from the view.
    var speed: Double = 60          // points per second (manual mode)
    var voiceFollow = false

    /// 0…1 reading progress reported by the speech recognizer, or nil if unavailable.
    var voiceProgress: Double? = nil

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var countdownTask: Task<Void, Never>?

    /// Half the first line's height, so we can center the first line on the focal line
    /// (not just align its top). Set by the view from the current font size.
    var firstLineLead: CGFloat = 0

    /// First line's center sits on the focal line.
    var startOffset: CGFloat { containerHeight * focalFraction - firstLineLead }
    /// Scroll until the last line has passed the focal line, plus a little run-off.
    var endOffset: CGFloat { startOffset - contentHeight - containerHeight * 0.18 }

    var progress: CGFloat {
        guard startOffset > endOffset else { return 0 }
        return min(1, max(0, (startOffset - offset) / (startOffset - endOffset)))
    }

    /// Reading position on voice mode's scale: 0 = first line on the reading
    /// line, 1 = last line on it. This is the fraction to seed the voice
    /// matcher with; `progress` runs on manual mode's longer scale (it includes
    /// the run-off) and would seed the matcher behind the reader.
    var textFraction: Double {
        guard contentHeight > 1 else { return 0 }
        return Double(min(1, max(0, (startOffset - offset) / contentHeight)))
    }

    /// Keep the first line parked at the start while idle. Re-runs on every layout
    /// change (the container size often arrives after the view's onAppear), so the
    /// text is reliably at the top before the user hits play - regardless of timing.
    private func pinToStartIfIdle() {
        guard !hasStarted, !isPlaying, !finished, containerHeight > 0 else { return }
        offset = startOffset
    }

    /// Marks that the user has taken control (dragged the text), so we stop auto-pinning.
    func markEngaged() { hasStarted = true }

    func startLink() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stopLink() {
        link?.invalidate()
        link = nil
        countdownTask?.cancel()
    }

    @objc private func step(_ link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
        let dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        advance(dt)
    }

    private func advance(_ dt: CFTimeInterval) {
        guard isPlaying, !finished, countdown == nil else { return }

        if voiceFollow {
            // Voice mode: the text only moves as far as the speaker has read. With no
            // speech yet (progress nil/0) it stays put - it must not constant-scroll.
            // Only ever move forward (a pause/stumble never jerks it back), with a
            // capped catch-up speed so recognition jumps resolve smoothly.
            let p = voiceProgress ?? 0
            // Align the word at fraction p of the script with the reading line.
            // Manual mode's endOffset includes a run-off past the last line; using
            // it here pushed the spoken line above the arrows, worse the further
            // into the script the reader got.
            let target = startOffset - CGFloat(p) * contentHeight
            let delta = target - offset                 // negative => scroll up
            if delta < 0 {
                // Close most of the gap within about 0.15s so the text visibly
                // tracks the speaker, but cap the sprint so a recognition jump
                // glides instead of teleporting.
                let eased = delta * min(1, CGFloat(dt) * 6.5)
                let maxStep = CGFloat(max(speed, 140)) * 3.0 * CGFloat(dt)
                offset += max(eased, -maxStep)
            }
            // The voice target never reaches manual mode's endOffset, so finish
            // explicitly once every word is matched and the scroll has settled.
            if contentHeight > 1, p >= 1, delta > -2 {
                isPlaying = false
                finished = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return
            }
        } else {
            offset -= CGFloat(speed) * CGFloat(dt)
        }

        // Only allow finishing once the script height is actually known, otherwise a
        // not-yet-measured script (contentHeight == 0) would "end" after a line or two.
        if contentHeight > 1, offset <= endOffset {
            offset = endOffset
            isPlaying = false
            finished = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Controls

    func togglePlay(countdownEnabled: Bool) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if finished { reset(); beginPlayback(countdownEnabled: countdownEnabled); return }
        if isPlaying {
            isPlaying = false
            cancelCountdown()
        } else {
            beginPlayback(countdownEnabled: countdownEnabled)
        }
    }

    func beginPlayback(countdownEnabled: Bool) {
        hasStarted = true
        let nearStart = abs(offset - startOffset) < 4
        if countdownEnabled && nearStart && !voiceFollow {
            startCountdown()
        } else {
            isPlaying = true
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
        }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        if countdown != nil { withAnimation { countdown = nil } }
    }

    func reset() {
        finished = false
        isPlaying = false
        hasStarted = false
        cancelCountdown()
        withAnimation(.easeOut(duration: 0.35)) { offset = startOffset }
    }

    func nudge(by delta: CGFloat) {
        offset += delta
        finished = false
    }
}
