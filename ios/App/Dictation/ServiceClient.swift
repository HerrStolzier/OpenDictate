import Foundation
import OpenDictateCore

/// Transcription and translation requests, built like the Mac app's
/// `OpenAITranscriber` and `OpenAITranslator` (`fixtures/provider/CONTRACT.md`).
struct ServiceClient: Sendable {
    /// The upload limit of `/audio/transcriptions`.
    static let maximumUploadBytes = 25 * 1_024 * 1_024

    private let transcriptionSession: URLSession
    private let translationSession: URLSession

    init() {
        transcriptionSession = RedirectBlocker.session(requestTimeout: 30, resourceTimeout: 120)
        // A stalled translation ends after 15 seconds without data.
        translationSession = RedirectBlocker.session(requestTimeout: 15, resourceTimeout: 60)
    }

    /// Contacts a custom server once from the foreground. iOS asks for local
    /// network access only then and denies it silently to a background upload
    /// (TN3179). Nothing but the address is sent, and the answer is ignored.
    func reach(_ endpoint: ServiceEndpoint) async {
        guard !endpoint.isOpenAI, !endpoint.isLoopback else { return }
        var request = URLRequest(url: endpoint.baseURL.appendingPathComponent("models"))
        request.timeoutInterval = 10
        _ = try? await translationSession.data(for: request)
    }

    func transcribe(_ audio: Data, configuration: DictationConfiguration) async throws -> String {
        let request = try Self.transcriptionRequest(audio: audio, configuration: configuration)
        let (data, response) = try await transcriptionSession.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw DictationFailure.invalidResponse }
        guard 200..<300 ~= response.statusCode else { throw Self.failure(data: data, status: response.statusCode) }
        struct Body: Decodable { let text: String }
        guard let body = try? JSONDecoder().decode(Body.self, from: data) else {
            throw DictationFailure.invalidResponse
        }
        return body.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func translate(_ text: String, into target: String, configuration: DictationConfiguration) async throws -> String {
        let request = try Self.translationRequest(text: text, target: target, configuration: configuration)
        let (data, response) = try await translationSession.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw DictationFailure.invalidResponse }
        guard 200..<300 ~= response.statusCode else { throw Self.failure(data: data, status: response.statusCode) }
        struct Body: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let body = try? JSONDecoder().decode(Body.self, from: data) else {
            throw DictationFailure.invalidResponse
        }
        return (body.choices.first?.message.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func transcriptionRequest(audio: Data, configuration: DictationConfiguration) throws -> URLRequest {
        guard !audio.isEmpty else { throw DictationFailure.tooShort }
        guard audio.count <= maximumUploadBytes else { throw DictationFailure.service(status: 413, code: nil) }
        let boundary = "OpenDictateBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: configuration.endpoint.transcriptionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        configuration.authorize(&request)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            let part = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"
            body.append(Data(part.utf8))
        }
        field("model", configuration.model.rawValue)
        field("response_format", "json")
        // A fixed transport filename keeps local paths out of the request.
        let fileHeader =
            "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n"
            + "Content-Type: audio/mp4\r\n\r\n"
        body.append(Data(fileHeader.utf8))
        body.append(audio)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        return request
    }

    /// The transcript goes in the user message as data; the target language is
    /// named only in the system message.
    static func translationRequest(text: String, target: String, configuration: DictationConfiguration) throws
        -> URLRequest
    {
        var request = URLRequest(url: configuration.endpoint.chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        configuration.authorize(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": configuration.translationModel,
            "messages": [
                ["role": "system", "content": Translation.instructions(target: target)],
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func failure(data: Data, status: Int) -> DictationFailure {
        struct Body: Decodable {
            struct Detail: Decodable {
                let code: String?
                let type: String?
            }
            let error: Detail
        }
        let detail = (try? JSONDecoder().decode(Body.self, from: data))?.error
        return .service(status: status, code: detail?.code ?? detail?.type)
    }
}

/// Refuses HTTP redirects, so audio and text go only to the validated address
/// and never on to a host the user did not configure.
final class RedirectBlocker: NSObject, URLSessionTaskDelegate, Sendable {
    static func session(requestTimeout: TimeInterval, resourceTimeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? { nil }
}
