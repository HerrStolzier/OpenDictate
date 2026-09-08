import Foundation
import Testing

@testable import OpenDictate

/// Explicit, attended integration check. Never reads arbitrary recordings or
/// uses credentials/network in the default suite or CI.
@Suite("Opt-in live transcription")
struct LiveTranscriptionTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OPENDICTATE_LIVE_API"] == "1"))
    func syntheticReference() async throws {
        let directory = try #require(ProcessInfo.processInfo.environment["OPENDICTATE_LIVE_TEST_DIRECTORY"])
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        let input = root.appendingPathComponent("reference.m4a")
        let data = try Data(contentsOf: input)
        try #require(!data.isEmpty && data.count < 1_000_000)
        // Never print, serialize or pass this key in an argument/environment.
        guard let key = KeychainAPIKeyStore.read() else {
            Issue.record("Existing OpenDictate Keychain credential is unavailable to this test process")
            return
        }
        let modelName = ProcessInfo.processInfo.environment["OPENDICTATE_LIVE_TEST_MODEL"] ?? "gpt-transcribe"
        try #require(["gpt-transcribe", "gpt-4o-mini-transcribe"].contains(modelName))
        let options = TranscriptionOptions(apiKey: key, model: .init(rawValue: modelName), language: "de", prompt: nil)
        let start = ContinuousClock.now
        let result = try await OpenAITranscriber().transcribe(audioData: data, options: options)
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let recognized =
            result.localizedCaseInsensitiveContains("Apfel")
            && result.localizedCaseInsensitiveContains("Test")
            && (result.localizedCaseInsensitiveContains("sieben") || result.contains("7"))
        struct Evidence: Encodable {
            let fixture: String
            let model: String
            let language: String
            let inputBytes: Int
            let elapsedSeconds: Double
            let expectedTermsRecognized: Bool
            let transcript: String
        }
        let evidence = Evidence(
            fixture: "macOS synthesized speech, not human microphone audio", model: modelName, language: "de",
            inputBytes: data.count, elapsedSeconds: seconds, expectedTermsRecognized: recognized, transcript: result)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(evidence).write(
            to: root.appendingPathComponent("api-result-\(modelName).json"), options: .atomic)
        #expect(recognized)
    }
}
