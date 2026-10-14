import AVFoundation
import XCTest

@testable import OpenDictateiOS

/// A silent recording is not sent; anything above room noise is.
final class SpeechCheckTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }

    func testSilenceIsNotSpeech() throws {
        try write(seconds: 2) { _ in 0 }
        XCTAssertFalse(SpeechCheck.heardSpeech(at: url))
    }

    func testRoomNoiseIsNotSpeech() throws {
        // About -60 dBFS.
        try write(seconds: 2) { _ in Float.random(in: -0.0017...0.0017) }
        XCTAssertFalse(SpeechCheck.heardSpeech(at: url))
    }

    func testAShortLoudPartIsSpeech() throws {
        // Silence with a quarter second of a -20 dBFS tone in the middle.
        try write(seconds: 2) { time in
            (0.9..<1.15).contains(time) ? 0.14 * sin(2 * .pi * 220 * Float(time)) : 0
        }
        XCTAssertTrue(SpeechCheck.heardSpeech(at: url))
    }

    func testUnreadableFileIsLeftToTheService() throws {
        try Data("not audio".utf8).write(to: url)
        XCTAssertTrue(SpeechCheck.heardSpeech(at: url))
    }

    private func write(seconds: Double, sample: (Double) -> Float) throws {
        let rate = 24_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let frames = AVAudioFrameCount(seconds * rate)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let data = try XCTUnwrap(buffer.floatChannelData)
        for frame in 0..<Int(frames) { data[0][frame] = sample(Double(frame) / rate) }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
