import Foundation
import OpenDictateCore
import Testing

@testable import OpenDictate

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseCode = 200
    nonisolated(unsafe) static var failure: URLError.Code?
    nonisolated(unsafe) static var body: Data?
    nonisolated(unsafe) static var advertisedLength: Int?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let code = Self.failure {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        var headers = ["Content-Type": "application/json"]
        if let advertisedLength = Self.advertisedLength {
            headers["Content-Length"] = String(advertisedLength)
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: Self.responseCode, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // A missing fixture fails here instead of surfacing as invalidResponse.
        guard let body = Self.body ?? (try? ProviderFixtures.data(ProviderFixtures.cases().success.file)) else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite("Offline URLSession transport", .serialized)
struct TranscriptionTransportTests {
    @Test func successAndNetworkFailures() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let transcriber = OpenAITranscriber(session: session)
        let options = TranscriptionOptions(apiKey: "fixture-only", model: .gptTranscribe, language: nil, prompt: nil)
        StubProtocol.failure = nil
        let expected = try ProviderFixtures.cases().success.text
        #expect(try await transcriber.transcribe(audioData: Data([1]), options: options) == expected)
        for failure in [URLError.Code.notConnectedToInternet, .timedOut, .cancelled] {
            StubProtocol.failure = failure
            do {
                _ = try await transcriber.transcribe(audioData: Data([1]), options: options)
                Issue.record("network failure must not become a successful transcript")
            } catch { #expect((error as? URLError)?.code == failure) }
        }
        StubProtocol.failure = nil
    }

    @Test("OpenAI text keeps its line breaks; only a server of your own gets segments joined")
    func openAILineBreaksStay() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            StubProtocol.body = nil
        }
        StubProtocol.body = Data(#"{"text":"Zeile eins\nZeile zwei"}"#.utf8)
        let options = TranscriptionOptions(apiKey: "fixture-only", model: .gptTranscribe, language: nil, prompt: nil)
        let text = try await OpenAITranscriber(session: session).transcribe(audioData: Data([1]), options: options)
        #expect(text == "Zeile eins\nZeile zwei")
    }

    @Test func oversizedProviderResponsesAreRejectedBeforeDecoding() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            StubProtocol.body = nil
            StubProtocol.advertisedLength = nil
        }
        let options = TranscriptionOptions(apiKey: "fixture-only", model: .gptTranscribe, language: nil, prompt: nil)
        StubProtocol.failure = nil

        StubProtocol.advertisedLength = BoundedProviderResponse.maximumBytes + 1
        StubProtocol.body = Data(#"{"text":"small"}"#.utf8)
        await #expect(throws: OpenDictateError.self) {
            try await OpenAITranscriber(session: session).transcribe(audioData: Data([1]), options: options)
        }

        StubProtocol.advertisedLength = nil
        let oversized: [String: Any] = [
            "choices": [["message": ["content": String(repeating: "a", count: BoundedProviderResponse.maximumBytes)]]]
        ]
        let oversizedData = try JSONSerialization.data(withJSONObject: oversized)
        #expect(
            try OpenAITranslator.decode(data: oversizedData, statusCode: 200).count
                == BoundedProviderResponse.maximumBytes)
        StubProtocol.body = oversizedData
        await #expect(throws: OpenDictateError.self) {
            try await OpenAITranslator(session: session).translate("Hallo", into: "en", options: options)
        }
    }
}
