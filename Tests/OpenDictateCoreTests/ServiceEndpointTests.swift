import Testing

@testable import OpenDictateCore

@Suite("Service endpoint")
struct ServiceEndpointTests {
    @Test(
        "Encrypted servers and servers on this Mac are accepted",
        arguments: [
            ("https://api.groq.com/openai/v1", false),
            ("http://127.0.0.1:8080/v1/", true),
            ("http://localhost:1234/v1", true),
            ("http://[::1]:8000/v1", true),
            ("https://127.0.0.1:8443/v1", true),
            ("HTTP://LOCALHOST:8000/v1", true)
        ])
    func acceptsAllowedAddresses(address: String, loopback: Bool) throws {
        let endpoint = try #require(ServiceEndpoint(address))
        #expect(endpoint.isLoopback == loopback)
        #expect(!endpoint.baseURL.absoluteString.hasSuffix("/"))
    }

    @Test(
        "Unencrypted network addresses, credentials and other schemes are rejected",
        arguments: [
            "http://192.168.1.5:8080/v1", "http://example.com/v1", "ftp://127.0.0.1/v1",
            "https://user:secret@example.com/v1", "https://example.com/v1?key=1", "https://example.com/v1#x",
            "", "127.0.0.1:8080", "not a url", "http://127.0.0.1.example.com/v1"
        ])
    func rejectsUnsafeAddresses(address: String) {
        #expect(ServiceEndpoint(address) == nil)
    }

    @Test("Request URLs append the OpenAI paths to the base address")
    func requestURLs() throws {
        #expect(
            ServiceEndpoint.openAI.transcriptionURL.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        let local = try #require(ServiceEndpoint("http://127.0.0.1:8080/v1/"))
        #expect(local.transcriptionURL.absoluteString == "http://127.0.0.1:8080/v1/audio/transcriptions")
        #expect(local.chatCompletionsURL.absoluteString == "http://127.0.0.1:8080/v1/chat/completions")
        #expect(local.host == "127.0.0.1")
    }

    @Test("Local model IDs pass, field-breaking names do not")
    func modelNames() {
        for name in ["gpt-transcribe", "Systran/faster-whisper-small", "llama3:8b", "qwen/qwen3-8b"] {
            #expect(ModelName.isValid(name))
        }
        for name in ["", "two words", "quote\"d", "line\nbreak", "../model", String(repeating: "a", count: 129)] {
            #expect(!ModelName.isValid(name))
        }
    }
}
