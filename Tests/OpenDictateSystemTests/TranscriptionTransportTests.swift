import Foundation
import Testing
@testable import OpenDictate

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseCode = 200
    nonisolated(unsafe) static var failure: URLError.Code?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let code = Self.failure {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.responseCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"text":"transport result"}"#.utf8))
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
        #expect(try await transcriber.transcribe(audioData: Data([1]), filename: "audio.m4a", options: options) == "transport result")
        for failure in [URLError.Code.notConnectedToInternet, .timedOut, .cancelled] {
            StubProtocol.failure = failure
            do {
                _ = try await transcriber.transcribe(audioData: Data([1]), filename: "audio.m4a", options: options)
                Issue.record("network failure must not become a successful transcript")
            } catch { #expect((error as? URLError)?.code == failure) }
        }
        StubProtocol.failure = nil
    }
}
