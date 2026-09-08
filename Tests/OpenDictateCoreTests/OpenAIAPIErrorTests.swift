import Foundation
import Testing

@testable import OpenDictateCore

@Suite("OpenAI error messages")
struct OpenAIAPIErrorTests {
    private func message(_ json: String, status: Int) -> String {
        OpenAIAPIErrorMessage.humanReadableMessage(from: Data(json.utf8), statusCode: status)
    }

    @Test("401 with an invalid key points at Set API Key")
    func invalidKey() {
        let text = message(
            #"{"error":{"message":"Incorrect API key","type":"invalid_request_error","code":"invalid_api_key"}}"#,
            status: 401)
        #expect(text.contains("not valid"))
        #expect(text.contains("Set API Key"))
    }

    @Test("429 for an exhausted quota talks about billing, not about waiting")
    func exhaustedQuota() {
        let text = message(
            #"{"error":{"message":"You exceeded your quota","type":"insufficient_quota","code":"insufficient_quota"}}"#,
            status: 429)
        #expect(text.contains("quota is exhausted"))
        #expect(text.contains("billing"))
    }

    @Test("429 for rate limiting tells the user to wait")
    func rateLimited() {
        let text = message(
            #"{"error":{"message":"Rate limit reached","type":"requests","code":"rate_limit_exceeded"}}"#, status: 429)
        #expect(text.contains("rate limiting"))
        #expect(text.contains("Wait a moment"))
    }

    @Test("413 with an unparseable body falls back to the status code")
    func malformedBody() {
        let text = message("<html>Request Entity Too Large</html>", status: 413)
        #expect(text == "OpenAI returned HTTP 413. Please try again in a moment.")
    }

    @Test("An empty body falls back to the status code")
    func emptyBody() {
        let text = OpenAIAPIErrorMessage.humanReadableMessage(from: Data(), statusCode: 500)
        #expect(text == "OpenAI returned HTTP 500. Please try again in a moment.")
    }

    @Test("An unknown code passes the server's own message through")
    func unknownCodeKeepsServerMessage() {
        let text = message(
            #"{"error":{"message":"Unsupported audio format.","type":"invalid_request_error","code":"unsupported_format"}}"#,
            status: 400)
        #expect(text.contains("Unsupported audio format."))
    }

    @Test("An unknown code with no message still falls back")
    func unknownCodeWithoutMessage() {
        let text = message(#"{"error":{"message":"","type":"weird","code":"weird"}}"#, status: 400)
        #expect(text == "OpenAI returned HTTP 400. Please try again in a moment.")
    }

    @Test("The type is used when no code is present")
    func fallsBackToType() {
        let text = message(#"{"error":{"message":"nope","type":"invalid_api_key"}}"#, status: 401)
        #expect(text.contains("not valid"))
    }
}
