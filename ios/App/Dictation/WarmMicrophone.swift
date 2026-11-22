@preconcurrency import AVFoundation
import Foundation

/// Holds the microphone open with `AVAudioEngine` while a warm session runs,
/// so the app keeps running in the background (audio background mode) and a
/// dictation from the keyboard starts without reconfiguring the audio session.
/// Between dictations the engine's samples are dropped; during one they go
/// into an AAC file. Follows Hex's keepalive (MIT, see
/// ios/Keyboard/THIRD_PARTY_NOTICES.md), but records from the same tap.
@MainActor
final class WarmMicrophone {
    struct Capture {
        let url: URL
        let duration: TimeInterval
    }

    private var engine: AVAudioEngine?
    private let sink = CaptureSink()
    private var captureURL: URL?
    private var sampleRate: Double = 0

    var isRunning: Bool { engine?.isRunning ?? false }
    var isCapturing: Bool { captureURL != nil }

    func start() throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: break
        case .denied: throw DictationFailure.microphoneDenied
        default: throw DictationFailure.microphoneNotAsked
        }
        stop()
        let session = AVAudioSession.sharedInstance()
        // Mixing never interrupts the app in front, and setting the category
        // only when it changes avoids iOS refusing it from the background.
        let options: AVAudioSession.CategoryOptions = [.mixWithOthers, .allowBluetoothA2DP]
        do {
            if session.category != .playAndRecord || session.categoryOptions != options {
                try session.setCategory(.playAndRecord, mode: .default, options: options)
            }
            try session.setActive(true)
        } catch {
            throw DictationFailure.recordingFailed("warm \((error as NSError).code)")
        }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw DictationFailure.recordingFailed("warm format")
        }
        // A tap with another format than the hardware's raises an exception Swift cannot catch.
        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.tap(into: sink))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw DictationFailure.recordingFailed("warm engine \((error as NSError).code)")
        }
        self.engine = engine
        sampleRate = format.sampleRate
    }

    /// Ends a running capture first; its file stays where it is.
    func stop() {
        _ = endCapture()
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func beginCapture(into url: URL) throws {
        guard let engine, engine.isRunning, captureURL == nil else {
            throw DictationFailure.recordingFailed("warm idle")
        }
        let format = engine.inputNode.inputFormat(forBus: 0)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let file: AVAudioFile
        do {
            file = try AVAudioFile(
                forWriting: url, settings: settings, commonFormat: format.commonFormat,
                interleaved: format.isInterleaved)
        } catch {
            throw DictationFailure.recordingFailed("warm file \((error as NSError).code)")
        }
        sampleRate = format.sampleRate
        sink.begin(file)
        captureURL = url
    }

    /// The finished file, or nil when nothing was captured.
    func endCapture() -> Capture? {
        guard let url = captureURL else { return nil }
        captureURL = nil
        let frames = sink.end()
        return Capture(url: url, duration: sampleRate > 0 ? Double(frames) / sampleRate : 0)
    }

    /// Runs on the audio thread, so it must not inherit the main actor.
    nonisolated private static func tap(into sink: CaptureSink) -> AVAudioNodeTapBlock {
        { buffer, _ in sink.write(buffer) }
    }
}

/// The file the tap writes into, swapped under a lock between the main
/// actor and the audio thread.
private final class CaptureSink: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var frames: AVAudioFramePosition = 0

    func begin(_ file: AVAudioFile) {
        lock.withLock {
            self.file = file
            frames = 0
        }
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.withLock {
            guard let file, (try? file.write(from: buffer)) != nil else { return }
            frames += AVAudioFramePosition(buffer.frameLength)
        }
    }

    /// Closes the file so its last block is on disk before anyone reads it.
    func end() -> AVAudioFramePosition {
        lock.withLock {
            file?.close()
            file = nil
            return frames
        }
    }
}
