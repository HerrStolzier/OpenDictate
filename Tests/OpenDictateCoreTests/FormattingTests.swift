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
