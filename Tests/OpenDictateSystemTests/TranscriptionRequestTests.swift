import Foundation
import Testing
import OpenDictateCore
@testable import OpenDictate

@Suite("Offline transcription API contract")
struct TranscriptionRequestTests {
    @Test(arguments: [TranscriptionModel.gptTranscribe, .gpt4oMiniTranscribe])
    func languageFieldMatchesModel(_ model: TranscriptionModel) throws {
        let request = try OpenAITranscriber.request(audioData: Data([1, 2]), filename: "private.m4a",
            options: .init(apiKey: "test-only", model: model, language: "de", prompt: nil))
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(body.contains(model == .gptTranscribe ? "name=\"languages[]\"" : "name=\"language\""))
        #expect(!body.contains(model == .gptTranscribe ? "name=\"language\"" : "name=\"languages[]\""))
        #expect(body.contains("\r\n\r\njson\r\n"))
        #expect(!body.contains("private.m4a"))
    }

    @Test func parsesTypedResponseAndRejectsMalformedSuccess() throws {
        #expect(try OpenAITranscriber.decode(data: Data(#"{"text":" Hallo "}"#.utf8), statusCode: 200) == "Hallo")
        #expect(throws: OpenDictateError.self) {
            try OpenAITranscriber.decode(data: Data("not a transcript".utf8), statusCode: 200)
        }
        #expect(throws: OpenDictateError.self) {
            try OpenAITranscriber.decode(data: Data(#"{"text":"must not paste"}"#.utf8), statusCode: 500)
        }
    }
}
