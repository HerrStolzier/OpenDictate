@preconcurrency import AVFoundation
import Foundation
import OpenDictateCore

@MainActor
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var url: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func start() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("opendictate-\(UUID().uuidString).m4a")

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

        guard recorder.record() else {
            throw OpenDictateError.recordingCouldNotStart
        }

        self.recorder = recorder
        self.url = fileURL
    }

    func stop() throws -> URL {
        guard let recorder, let url else {
            throw OpenDictateError.noActiveRecording
        }

        recorder.stop()
        self.recorder = nil
        self.url = nil

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OpenDictateError.noAudioFile
        }

        return url
    }
}
