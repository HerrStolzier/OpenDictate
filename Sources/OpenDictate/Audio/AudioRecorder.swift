@preconcurrency import AVFoundation
import Foundation
import OpenDictateCore

@MainActor
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var url: URL?
    var onUnexpectedStop: (() -> Void)?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    func start() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("opendictate-\(UUID().uuidString).m4a")

        var started = false
        defer { if !started { try? FileManager.default.removeItem(at: fileURL) } }
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 24_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 48_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true

        guard recorder.record(forDuration: Config.maximumRecordingDuration) else {
            throw OpenDictateError.recordingCouldNotStart
        }

        self.recorder = recorder
        self.url = fileURL
        started = true
    }

    func level() -> Float {
        guard let recorder, recorder.isRecording else { return -160 }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    func stop() throws -> URL {
        guard let recorder, let url else {
            throw OpenDictateError.noActiveRecording
        }

        recorder.delegate = nil
        recorder.stop()
        self.recorder = nil
        self.url = nil

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OpenDictateError.noAudioFile
        }

        return url
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let identity = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let active = self.recorder, ObjectIdentifier(active) == identity else { return }
            self.onUnexpectedStop?()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let identity = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let active = self.recorder, ObjectIdentifier(active) == identity else { return }
            self.onUnexpectedStop?()
        }
    }
}
