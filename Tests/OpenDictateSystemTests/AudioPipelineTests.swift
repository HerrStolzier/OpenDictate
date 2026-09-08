@preconcurrency import AVFoundation
import Foundation
import Testing
import OpenDictateCore
@testable import OpenDictate

@Suite("Synthetic audio pipeline")
struct AudioPipelineTests {
    /// Synthetic tones verify levels and boundaries, not speech recognition.
    func fixture(seconds: Double, start: Double, end: Double, amplitude: Float, aac: Bool = false) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio-test-\(UUID()).\(aac ? "m4a" : "wav")")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(seconds * 24_000)))
        buffer.frameLength = buffer.frameCapacity
        let samples = try #require(buffer.floatChannelData?[0])
        for index in 0..<Int(buffer.frameLength) {
            let t = Double(index) / 24_000
            samples[index] = (t >= start && t < end) ? amplitude * Float(sin(t * 2 * .pi * 220)) : 0
        }
        let settings: [String: Any] = aac ? [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 24_000,
            AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 48_000
        ] : format.settings
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
        return url
    }

    @Test func silentAndQuietFilesAreDistinguishedByMeasuredLevel() throws {
        let silent = try fixture(seconds: 2, start: 0, end: 0, amplitude: 0)
        let quiet = try fixture(seconds: 2, start: 0, end: 2, amplitude: 0.001)
        defer { try? FileManager.default.removeItem(at: silent); try? FileManager.default.removeItem(at: quiet) }
        let silence = try AudioPreprocessor.analyze(audioURL: silent)
        let low = try AudioPreprocessor.analyze(audioURL: quiet)
        #expect(silence.speechRange == nil && low.speechRange == nil)
        #expect(low.peakDb > silence.peakDb)
    }

    @Test func detectsWindowBoundariesAndExportsPlayableAudio() async throws {
        let original = try fixture(seconds: 3, start: 1, end: 2, amplitude: 0.2)
        defer { try? FileManager.default.removeItem(at: original) }
        let analysis = try AudioPreprocessor.analyze(audioURL: original)
        let range = try #require(analysis.speechRange)
        #expect(abs(range.start - 1) <= 0.05 && abs(range.end - 2) <= 0.05)
        let prepared = try await AudioPreprocessor.prepare(audioURL: original)
        defer { if prepared.url != original { try? FileManager.default.removeItem(at: prepared.url) } }
        #expect(prepared.url != original)
        let result = try AVAudioFile(forReading: prepared.url)
        #expect(result.length > 0)
        #expect(prepared.uploadDuration >= 1 && prepared.uploadDuration <= 1.6)
    }

    @Test func shortDetectedSpanDoesNotPretendThereWasNoAudio() throws {
        let url = try fixture(seconds: 3, start: 1, end: 1.2, amplitude: 0.2)
        defer { try? FileManager.default.removeItem(at: url) }
        let analysis = try AudioPreprocessor.analyze(audioURL: url)
        #expect(analysis.speechRange != nil)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["OPENDICTATE_BENCHMARK"] == "1"))
    func benchmark() async throws {
        let url = try fixture(seconds: 90, start: 0.2, end: 89.7, amplitude: 0.2, aac: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let originalBytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        var rows = ["phase,iteration,milliseconds,bytes", "original,0,0,\(originalBytes)"]
        for index in 0..<7 {
            var start = ContinuousClock.now
            _ = try AudioPreprocessor.analyze(audioURL: url)
            var d = start.duration(to: .now)
            rows.append("analyze,\(index),\(Double(d.components.seconds)*1000+Double(d.components.attoseconds)/1e15),0")
            start = .now
            let export = try await AudioPreprocessor.exportTrimmedAudio(from: url, start: 0.2, duration: 89.5)
            d = start.duration(to: .now)
            let bytes = (try FileManager.default.attributesOfItem(atPath: export.path)[.size] as? NSNumber)?.intValue ?? 0
            rows.append("export,\(index),\(Double(d.components.seconds)*1000+Double(d.components.attoseconds)/1e15),\(bytes)")
            try FileManager.default.removeItem(at: export)
        }
        if let destination = ProcessInfo.processInfo.environment["OPENDICTATE_BENCHMARK_OUTPUT"] {
            try (rows.joined(separator: "\n") + "\n").write(toFile: destination, atomically: true, encoding: .utf8)
        }
    }
}
