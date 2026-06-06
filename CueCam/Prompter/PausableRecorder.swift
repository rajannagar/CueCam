import Foundation
import AVFoundation

/// Writes camera + mic sample buffers to a single .mov via AVAssetWriter, with support
/// for pause/resume (paused time is removed so the file is continuous) and for the
/// camera being switched mid-recording (the writer keeps going across the swap).
///
/// All mutable state is touched only on `queue` for thread safety.
final class PausableRecorder {
    private let queue = DispatchQueue(label: "cuecam.recorder")

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?

    private var recording = false
    private var paused = false
    private var sessionStarted = false
    private var discontinuity = false
    private var timeOffset = CMTime.zero
    private var lastRawPTS = CMTime.invalid

    private(set) var outputURL: URL?

    var isRecording: Bool { queue.sync { recording } }

    // MARK: - Lifecycle

    func start(videoSettings: [String: Any]?, audioSettings: [String: Any]?) {
        queue.async {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return }

            let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            vIn.expectsMediaDataInRealTime = true
            if writer.canAdd(vIn) { writer.add(vIn) }

            let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aIn.expectsMediaDataInRealTime = true
            if writer.canAdd(aIn) { writer.add(aIn) }

            writer.startWriting()

            self.writer = writer
            self.videoInput = vIn
            self.audioInput = aIn
            self.outputURL = url
            self.recording = true
            self.paused = false
            self.sessionStarted = false
            self.discontinuity = false
            self.timeOffset = .zero
            self.lastRawPTS = .invalid
        }
    }

    func pause() { queue.async { if self.recording { self.paused = true } } }

    func resume() {
        queue.async {
            if self.recording && self.paused {
                self.paused = false
                self.discontinuity = true       // recompute the time gap on the next sample
            }
        }
    }

    func finish(completion: @escaping (URL?) -> Void) {
        queue.async {
            guard self.recording, let writer = self.writer else { completion(nil); return }
            self.recording = false
            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()
            let url = self.outputURL
            writer.finishWriting {
                let ok = writer.status == .completed
                DispatchQueue.main.async { completion(ok ? url : nil) }
                self.writer = nil
                self.videoInput = nil
                self.audioInput = nil
            }
        }
    }

    // MARK: - Sample intake (called from the capture delegate queue)

    func append(_ sampleBuffer: CMSampleBuffer, isVideo: Bool) {
        queue.async {
            guard self.recording, !self.paused,
                  let writer = self.writer, writer.status == .writing else { return }

            let rawPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if !self.sessionStarted {
                // Start the timeline on the first sample (prefer a video sample).
                if isVideo {
                    writer.startSession(atSourceTime: rawPTS)
                    self.sessionStarted = true
                } else {
                    return // wait for first video sample
                }
            }

            if self.discontinuity {
                if self.lastRawPTS.isValid {
                    self.timeOffset = self.timeOffset + (rawPTS - self.lastRawPTS)
                }
                self.discontinuity = false
            }

            guard let adjusted = Self.retime(sampleBuffer, by: self.timeOffset) else { return }
            let dur = CMSampleBufferGetDuration(sampleBuffer)
            self.lastRawPTS = dur.isValid ? rawPTS + dur : rawPTS

            let input = isVideo ? self.videoInput : self.audioInput
            if let input, input.isReadyForMoreMediaData {
                input.append(adjusted)
            }
        }
    }

    /// Returns a copy of the sample buffer with its timestamps shifted back by `offset`.
    private static func retime(_ sample: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        if offset == .zero { return sample }
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        guard count > 0 else { return sample }
        var info = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: count, arrayToFill: &info, entriesNeededOut: &count)
        for i in 0..<count {
            if info[i].presentationTimeStamp.isValid {
                info[i].presentationTimeStamp = info[i].presentationTimeStamp - offset
            }
            if info[i].decodeTimeStamp.isValid {
                info[i].decodeTimeStamp = info[i].decodeTimeStamp - offset
            }
        }
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample,
                                              sampleTimingEntryCount: count,
                                              sampleTimingArray: &info, sampleBufferOut: &out)
        return out
    }
}
