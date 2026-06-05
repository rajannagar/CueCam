import SwiftUI
import QuartzCore

/// Single source of truth for scroll position and playback, shared by both the
/// screen prompter and the camera prompter. Driven by a CADisplayLink for buttery
/// 120Hz-capable motion.
@MainActor
final class PrompterEngine: NSObject, ObservableObject {
    @Published var offset: CGFloat = 0
    @Published var isPlaying = false
    @Published var finished = false
    @Published var countdown: Int? = nil

    /// Layout, set by the view.
    var contentHeight: CGFloat = 0
    var containerHeight: CGFloat = 0 { didSet { positionAtStartIfIdle() } }
    let focalFraction: CGFloat = 0.40

    /// Whether the text has been parked at its starting position for the current layout.
    private var positioned = false

    /// Config, synced from the view.
    var speed: Double = 60          // points per second (manual mode)
    var voiceFollow = false

    /// 0…1 reading progress reported by the speech recognizer, or nil if unavailable.
    var voiceProgress: Double? = nil

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var countdownTask: Task<Void, Never>?

    /// First line sits at the focal line.
    var startOffset: CGFloat { containerHeight * focalFraction }
    /// Scroll until the last line has passed the focal line, plus a little run-off.
    var endOffset: CGFloat { startOffset - contentHeight - containerHeight * 0.18 }

    var progress: CGFloat {
        guard startOffset > endOffset else { return 0 }
        return min(1, max(0, (startOffset - offset) / (startOffset - endOffset)))
    }

    /// Park the text at the start once we know the container size (layout can arrive
    /// after the view's onAppear), so the first line begins at the focal line.
    private func positionAtStartIfIdle() {
        guard !positioned, !isPlaying, !finished, containerHeight > 0 else { return }
        offset = startOffset
        positioned = true
    }

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

        if voiceFollow, let p = voiceProgress {
            // Ease toward the position that matches how far the speaker has read.
            let target = startOffset - CGFloat(p) * (startOffset - endOffset)
            offset += (target - offset) * min(1, CGFloat(dt) * 6)
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
        positioned = true
        cancelCountdown()
        withAnimation(.easeOut(duration: 0.35)) { offset = startOffset }
    }

    func nudge(by delta: CGFloat) {
        offset += delta
        finished = false
    }
}
