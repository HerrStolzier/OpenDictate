import Foundation
import OpenDictateCore

/// Translates a finished transcript with a text model. The transcript goes in
/// the user message as data; the target language is named only in the
/// system message.
struct OpenAITranslator: Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            // A stalled request ends after 15 seconds without data instead of
            // keeping the dictation in processing for minutes.
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 60
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            self.session = URLSession(configuration: configuration)
        }
    }

    func translate(_ text: String, into target: String, options: TranscriptionOptions? = nil) async throws -> String {
        let options = try options ?? .current()
        let request = try Self.request(text: text, target: target, options: options)
        try Task.checkCancellation()
        let timing = PhaseTiming(phase: "translation")
        defer { timing.finish() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw OpenDictateError.invalidResponse }
        return try Self.decode(data: data, statusCode: response.statusCode)
    }

    static func request(text: String, target: String, options: TranscriptionOptions) throws -> URLRequest {
        guard Translation.isValidLanguageCode(target), Translation.isValidModel(options.translationModel) else {
            throw OpenDictateError.translationNotConfigured
        }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("Bearer \(options.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": options.translationModel,
            "messages": [
                ["role": "system", "content": Translation.instructions(target: target)],
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Returns the trimmed translation; an empty result is left to the caller,
    /// which must not fall back to the original transcript.
    static func decode(data: Data, statusCode: Int) throws -> String {
        guard 200..<300 ~= statusCode else {
            throw OpenDictateError.apiError(
                OpenAIAPIErrorMessage.humanReadableMessage(from: data, statusCode: statusCode))
        }
        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let result = try? JSONDecoder().decode(Response.self, from: data) else {
            throw OpenDictateError.invalidResponse
        }
        return (result.choices.first?.message.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
