import Foundation
import Testing

@testable import OpenDictateCore

@Suite("OpenAI error messages")
struct OpenAIAPIErrorTests {
    private func message(_ json: String, status: Int) -> String {
        OpenAIAPIErrorMessage.humanReadableMessage(from: Data(json.utf8), statusCode: status)
    }

    @Test("429 for an exhausted quota talks about billing, not about waiting")
    func exhaustedQuota() {
        let text = message(
            #"{"error":{"message":"You exceeded your quota","type":"insufficient_quota","code":"insufficient_quota"}}"#,
            status: 429)
        #expect(text.contains("aufgebraucht"))
        #expect(text.contains("Budget"))
    }

    @Test("429 for rate limiting tells the user to wait")
    func rateLimited() {
        let text = message(
            #"{"error":{"message":"Rate limit reached","type":"requests","code":"rate_limit_exceeded"}}"#, status: 429)
        #expect(text.contains("Zu viele Anfragen"))
        #expect(text.contains("Warte einen Moment"))
    }

    @Test("An unknown code does not expose raw provider text")
    func unknownCodeHidesServerMessage() {
        let text = message(
            #"{"error":{"message":"Unsupported audio format.","type":"invalid_request_error","code":"unsupported_format"}}"#,
            status: 400)
        #expect(!text.contains("Unsupported audio format."))
        #expect(text.contains("Hilfe"))
    }

    @Test("The type is used when no code is present")
    func fallsBackToType() {
        let text = message(#"{"error":{"message":"nope","type":"invalid_api_key"}}"#, status: 401)
        #expect(text.contains("ungültig"))
    }
}
