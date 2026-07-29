import Foundation
import Testing
@testable import OpenDictateCore

@Suite("Formatting")
struct FormattingTests {
    @Test("Seconds always carry exactly one decimal", arguments: [
        (0.0, "0.0s"),
        (1.0, "1.0s"),
        (0.44, "0.4s"),
        (1.96, "2.0s"),
        (90.0, "90.0s"),
        (-1.0, "-1.0s")
    ])
    func formattedSeconds(value: TimeInterval, expected: String) {
        #expect(value.formattedSeconds == expected)
    }

    @Test("Decibels are whole numbers with a unit", arguments: [
        (Float(-45), "-45 dB"),
        (Float(-140), "-140 dB"),
        (Float(0), "0 dB"),
        (Float(-59.6), "-60 dB")
    ])
    func formattedDb(value: Float, expected: String) {
        #expect(value.formattedDb == expected)
    }

    @Test("appendString writes UTF-8 without a separator")
    func appendString() {
        var data = Data()
        data.appendString("a=1\r\n")
        data.appendString("ü")
        #expect(String(data: data, encoding: .utf8) == "a=1\r\nü")
    }
}

@Suite("Error descriptions")
struct OpenDictateErrorTests {
    @Test("Skipped recordings are distinguished from real failures")
    func skippedClassification() {
        #expect(OpenDictateError.noSpeechDetected(peakDb: -70).isSkippedRecording)
        #expect(OpenDictateError.recordingTooShort(actual: 0.4, minimum: 1).isSkippedRecording)
        #expect(!OpenDictateError.invalidResponse.isSkippedRecording)
        #expect(!OpenDictateError.apiError("boom").isSkippedRecording)
        #expect(!OpenDictateError.missingAPIKey.isSkippedRecording)
    }

    @Test("The too-short message names both durations")
    func tooShortMessage() {
        let text = OpenDictateError.recordingTooShort(actual: 0.4, minimum: 1).errorDescription
        #expect(text?.contains("0.4s") == true)
        #expect(text?.contains("1.0s") == true)
    }

    @Test("The no-speech message names the measured peak")
    func noSpeechMessage() {
        let text = OpenDictateError.noSpeechDetected(peakDb: -63.2).errorDescription
        #expect(text?.contains("-63 dB") == true)
    }
}
