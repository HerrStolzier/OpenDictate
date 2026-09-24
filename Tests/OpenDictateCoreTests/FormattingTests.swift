import Foundation
import Testing

@testable import OpenDictateCore

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

    @Test("The low-level message offers microphone guidance without raw measurements")
    func noSpeechMessage() {
        let text = OpenDictateError.noSpeechDetected(peakDb: -63.2).errorDescription
        #expect(text?.contains("Mikrofon") == true)
        #expect(text?.contains("-63") == false)
    }
    @Test("Framework errors offer a safe next action without leaking raw details")
    func frameworkMessage() {
        let error = NSError(
            domain: "Test", code: 42,
            userInfo: [NSLocalizedDescriptionKey: "private raw framework details"])
        let message = OpenDictateError.userMessage(for: error)
        #expect(!message.contains("private raw"))
        #expect(message.contains("Hilfe"))
        let audio = OpenDictateError.audioPreprocessingFailed("raw export details")
        #expect(!OpenDictateError.userMessage(for: audio).contains("raw export"))
    }

}
