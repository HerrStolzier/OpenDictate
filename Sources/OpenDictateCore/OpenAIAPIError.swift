import Foundation

public enum OpenAIAPIErrorMessage {
    struct Body: Decodable {
        let error: Detail
    }

    struct Detail: Decodable {
        let message: String?
        let type: String?
        let code: String?
    }

    public static func humanReadableMessage(from data: Data, statusCode: Int) -> String {
        let fallback = "OpenAI returned HTTP \(statusCode). Please try again in a moment."

        guard
            let body = try? JSONDecoder().decode(Body.self, from: data)
        else {
            return fallback
        }

        switch body.error.code ?? body.error.type {
        case "insufficient_quota":
            return """
            Your OpenAI API quota is exhausted.

            OpenAI accepted the request, but the API account or project behind this key has no remaining credit or has reached its usage limit.

            Check your OpenAI billing, project budget, or usage limits, then try again.
            """
        case "invalid_api_key":
            return """
            The OpenAI API key is not valid.

            Open the OpenDictate menu, choose Set API Key..., and paste a valid API key.
            """
        case "billing_not_active":
            return """
            OpenAI API billing is not active for this account or project.

            Add a billing method or choose an API key from a project with billing enabled.
            """
        case "rate_limit_exceeded":
            return """
            OpenAI is rate limiting this API key right now.

            Wait a moment and try again.
            """
        default:
            if let message = body.error.message, !message.isEmpty {
                return "OpenAI could not transcribe this recording.\n\n\(message)"
            }
            return fallback
        }
    }
}
