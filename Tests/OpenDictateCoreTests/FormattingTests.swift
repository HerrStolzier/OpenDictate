import Foundation
import Testing

@testable import OpenDictateCore

@Suite("Error descriptions")
struct OpenDictateErrorTests {
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

    @Test("The too-short message uses German number formatting")
    func tooShortMessage() {
        let message = OpenDictateError.recordingTooShort(actual: 0.44, minimum: 1).errorDescription ?? ""
        #expect(message.contains("(0,4 s)"))
        #expect(message.contains("mindestens 1 s "))
    }

}
