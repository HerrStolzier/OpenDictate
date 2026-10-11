import Foundation
import OpenDictateCore
import Testing

@testable import OpenDictate

@Suite("Offline transcription API contract")
struct TranscriptionRequestTests {
    @Test(arguments: [TranscriptionModel.gptTranscribe, .gpt4oMiniTranscribe])
    func languageFieldMatchesModel(_ model: TranscriptionModel) throws {
        let request = try OpenAITranscriber.request(
            audioData: Data([1, 2]),
            options: .init(apiKey: "test-only", model: model, language: "de", prompt: nil))
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        #expect(body.contains(model == .gptTranscribe ? "name=\"languages[]\"" : "name=\"language\""))
        #expect(!body.contains(model == .gptTranscribe ? "name=\"language\"" : "name=\"languages[]\""))
        #expect(body.contains("\r\n\r\njson\r\n"))
        #expect(body.contains("filename=\"recording.m4a\""))
    }

    @Test func defaultAddressStaysOpenAIWithKey() throws {
        let request = try OpenAITranscriber.request(
            audioData: Data([1]), options: .init(apiKey: "test-only", model: .gptTranscribe, language: nil, prompt: nil)
        )
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only")
    }

    @Test func customHTTPSServerGetsTheStoredKey() throws {
        let options = TranscriptionOptions(
            apiKey: "test-only", model: .init(rawValue: "whisper-large-v3"), language: "de", prompt: nil,
            endpoint: try #require(ServiceEndpoint("https://api.groq.com/openai/v1")))
        let request = try OpenAITranscriber.request(audioData: Data([1]), options: options)
        #expect(request.url?.absoluteString == "https://api.groq.com/openai/v1/audio/transcriptions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only")
        #expect(String(decoding: request.httpBody!, as: UTF8.self).contains("whisper-large-v3"))
    }

    @Test func localServerNeverReceivesTheKey() throws {
        let options = TranscriptionOptions(
            apiKey: "must-not-leave", model: .init(rawValue: "Systran/faster-whisper-small"), language: "de",
            prompt: nil, endpoint: try #require(ServiceEndpoint("http://localhost:8000/v1")))
        let request = try OpenAITranscriber.request(audioData: Data([1]), options: options)
        #expect(request.url?.absoluteString == "http://localhost:8000/v1/audio/transcriptions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(!String(decoding: request.httpBody!, as: UTF8.self).contains("must-not-leave"))
    }

    @Test func localUploadChecksDoNotUseInvalidResponse() {
        let options = TranscriptionOptions(
            apiKey: "test-only", model: .gptTranscribe, language: nil, prompt: nil)
        do {
            _ = try OpenAITranscriber.request(audioData: Data(), options: options)
            Issue.record("empty audio should be rejected")
        } catch OpenDictateError.audioNotEligibleForUpload {
        } catch { Issue.record("empty audio used \(error)") }

        do {
            _ = try OpenAITranscriber.request(
                audioData: Data(count: 25 * 1_024 * 1_024 + 1), options: options)
            Issue.record("oversized audio should be rejected")
        } catch OpenDictateError.audioNotEligibleForUpload {
        } catch { Issue.record("oversized audio used \(error)") }

        do {
            _ = try OpenAITranscriber.request(
                audioData: Data([1]),
                options: .init(apiKey: "test-only", model: .gptLiveTranscribe, language: nil, prompt: nil))
            Issue.record("realtime model should be rejected")
        } catch OpenDictateError.unusableTranscriptionModel {
        } catch { Issue.record("realtime model used \(error)") }
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
