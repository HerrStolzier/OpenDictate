@preconcurrency import AVFoundation
import Foundation
import UIKit

/// The microphone, recorded as AAC in an `.m4a` file with the Mac's settings.
/// The `audio` background mode keeps it running while another app is in front.
@MainActor
final class Recorder: NSObject, AVAudioRecorderDelegate {
    struct Recording {
        let url: URL
        let duration: TimeInterval
    }

    private var recorder: AVAudioRecorder?
    private var startedAt: Date?
    private var limit: TimeInterval = 0
    /// The limit, an interruption or an encoder error ended the recording.
    var onUnexpectedStop: (() -> Void)?

    static var permission: AVAudioApplication.recordPermission { AVAudioApplication.shared.recordPermission }

    static func requestPermission() async -> Bool { await AVAudioApplication.requestRecordPermission() }

    func start(into url: URL, limit: TimeInterval) throws {
        switch Self.permission {
        case .granted: break
        case .denied: throw DictationFailure.microphoneDenied
        default: throw DictationFailure.microphoneNotAsked
        }
        let session = AVAudioSession.sharedInstance()
        let inBackground = UIApplication.shared.applicationState == .background
        do {
            if inBackground {
                // A session that interrupts the app in front may not start
                // from the background; ducking mixes with it instead.
                try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
            } else {
                try session.setCategory(.record, mode: .default)
            }
        } catch {
            throw DictationFailure.recordingFailed("category \((error as NSError).code)")
        }
        do {
            try session.setActive(true)
        } catch {
            throw DictationFailure.recordingFailed("\(inBackground ? "background" : "app") \((error as NSError).code)")
        }
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 24_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 48_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            Self.releaseSession()
            throw DictationFailure.recordingFailed("recorder \((error as NSError).code)")
        }
        recorder.delegate = self
        guard recorder.record(forDuration: limit) else {
            Self.releaseSession()
            try? FileManager.default.removeItem(at: url)
            throw DictationFailure.recordingFailed("record")
        }
        self.recorder = recorder
        self.limit = limit
        startedAt = Date()
    }

    /// Ends the recording and hands the microphone back, so the orange
    /// indicator goes off and other audio can resume.
    func stop() -> Recording? {
        guard let recorder, let startedAt else { return nil }
        recorder.delegate = nil
        recorder.stop()
        self.recorder = nil
        self.startedAt = nil
        Self.releaseSession()
        // The clock, because the recorder resets `currentTime` once it stopped
        // itself at the limit.
        return Recording(url: recorder.url, duration: min(limit, Date().timeIntervalSince(startedAt)))
    }

    private static func releaseSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        notifyUnexpectedStop(for: recorder)
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        notifyUnexpectedStop(for: recorder)
    }

    private nonisolated func notifyUnexpectedStop(for recorder: AVAudioRecorder) {
        let identity = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let active = self.recorder, ObjectIdentifier(active) == identity else { return }
            self.onUnexpectedStop?()
        }
    }
}
