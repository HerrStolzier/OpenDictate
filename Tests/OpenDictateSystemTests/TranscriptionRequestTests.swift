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

    @Test("A server of your own gets segment breaks joined; OpenAI text keeps its lines")
    func joinsSegmentsOnlyForOwnServer() throws {
        let whisper = Data(#"{"text":" Satz eins.\n Satz zwei.\n"}"#.utf8)
        #expect(
            try OpenAITranscriber.decode(data: whisper, statusCode: 200, joinSegments: true) == "Satz eins. Satz zwei.")
        let openAI = Data(#"{"text":"Zeile eins\nZeile zwei"}"#.utf8)
        #expect(try OpenAITranscriber.decode(data: openAI, statusCode: 200) == "Zeile eins\nZeile zwei")
    }

    @Test func parsesTheSharedSuccessFixtureAndRejectsMalformedSuccess() throws {
        let success = try ProviderFixtures.cases().success
        let data = try ProviderFixtures.data(success.file)
        #expect(try OpenAITranscriber.decode(data: data, statusCode: success.status) == success.text)
        #expect(throws: OpenDictateError.self) {
            try OpenAITranscriber.decode(data: Data("not a transcript".utf8), statusCode: 200)
        }
        #expect(throws: OpenDictateError.self) {
            try OpenAITranscriber.decode(data: Data(#"{"text":"must not paste"}"#.utf8), statusCode: 500)
        }
    }

    @Test func sharedErrorFixturesBecomeOwnMessagesWithoutProviderText() throws {
        for failure in try ProviderFixtures.cases().errors {
            let data = try ProviderFixtures.data(failure.file)
            do {
                _ = try OpenAITranscriber.decode(data: data, statusCode: failure.status)
                Issue.record("\(failure.file) must not become a transcript")
            } catch {
                let message = OpenDictateError.userMessage(for: error)
                #expect(message.contains(failure.macMessageContains), "\(failure.file): \(message)")
                let raw = try #require(
                    (try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]])?["error"]?["message"]
                        as? String)
                #expect(!message.contains(raw))
            }
        }
    }

    @Test func multipartFieldsFollowTheContractOrder() throws {
        let request = try OpenAITranscriber.request(
            audioData: Data([1]),
            options: .init(apiKey: "test-only", model: .gptTranscribe, language: "de", prompt: "Begriffe"))
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        let names = ["model", "response_format", "languages[]", "prompt", "file"].map { "name=\"\($0)\"" }
        let positions = try names.map { try #require(body.range(of: $0)?.lowerBound) }
        #expect(positions == positions.sorted())
        #expect(body.contains("filename=\"recording.m4a\"\r\nContent-Type: audio/mp4"))
    }
}
