import Foundation
import OpenDictateCore

struct TranscriptionOptions: Sendable {
    /// nil for a server on this Mac: it gets no key, and none is required.
    let apiKey: String?
    let endpoint: ServiceEndpoint
    let model: TranscriptionModel
    let language: String?
    let prompt: String?
    /// Captured with the other options, so a menu change during processing
    /// applies to the next dictation.
    let translationTarget: String?
    let translationModel: String

    init(
        apiKey: String?, model: TranscriptionModel, language: String?, prompt: String?,
        translationTarget: String? = nil, translationModel: String = Translation.defaultModel,
        endpoint: ServiceEndpoint = .openAI
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
        self.language = language
        self.prompt = prompt
        self.translationTarget = translationTarget
        self.translationModel = translationModel
    }

    /// Options for the chosen service, or for `service` when the user picked
    /// another one for a single resend.
    static func current(service: Settings.Service? = nil) throws -> Self {
        let settings = Config.settings
        let service = service ?? settings.service
        // An invalid configured address stops the dictation; falling back to
        // OpenAI would send audio where the user chose not to.
        guard let endpoint = settings.endpoint(for: service) else { throw OpenDictateError.invalidServerAddress }
        let key: String?
        if endpoint.isLoopback {
            key = nil
        } else {
            guard let stored = Config.apiKey else { throw OpenDictateError.missingAPIKey }
            key = stored
        }
        let model = settings.model(for: service)
        guard model.isUsableForUpload else { throw OpenDictateError.unusableTranscriptionModel }
        return Self(
            apiKey: key, model: model, language: Config.language, prompt: Config.prompt,
            translationTarget: settings.translationTarget,
            translationModel: settings.translationModel(for: service), endpoint: endpoint)
    }

    /// Sets the bearer header only when a key belongs to this request.
    func authorize(_ request: inout URLRequest) {
        guard let apiKey, !endpoint.isLoopback else { return }
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
}

/// Refuses HTTP redirects, so audio and text go only to the validated address
/// and never on to a host the user did not configure. The redirect response
/// itself is then reported as a service error.
final class RedirectBlocker: NSObject, URLSessionTaskDelegate, Sendable {
    static func session(_ configuration: URLSessionConfiguration) -> URLSession {
        URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? { nil }
}

struct OpenAITranscriber: Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 120
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            self.session = RedirectBlocker.session(configuration)
        }
    }

    func transcribe(audioURL: URL, options: TranscriptionOptions? = nil) async throws -> String {
        try Task.checkCancellation()
        return try await transcribe(audioData: Data(contentsOf: audioURL), options: options)
    }

    func transcribe(audioData: Data, options: TranscriptionOptions? = nil) async throws -> String {
        let options = try options ?? .current()
        let request = try Self.request(audioData: audioData, options: options)
        try Task.checkCancellation()
        let timing = PhaseTiming(phase: "request")
        defer { timing.finish() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw OpenDictateError.invalidResponse }
        return try Self.decode(
            data: data, statusCode: response.statusCode, joinSegments: options.endpoint != .openAI)
    }

    static func request(audioData: Data, options: TranscriptionOptions) throws -> URLRequest {
        guard options.model.isUsableForUpload else { throw OpenDictateError.unusableTranscriptionModel }
        guard !audioData.isEmpty, audioData.count <= 25 * 1_024 * 1_024 else {
            throw OpenDictateError.audioNotEligibleForUpload
        }
        let boundary = "OpenDictateBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: options.endpoint.transcriptionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        options.authorize(&request)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.appendString("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        field("model", options.model.rawValue)
        field("response_format", "json")
        if let language = options.language, !language.isEmpty {
            field(options.model == .gptTranscribe ? "languages[]" : "language", language)
        }
        if let prompt = options.prompt, !prompt.isEmpty { field("prompt", prompt) }
        // The endpoint detects the container. A fixed transport filename avoids
        // carrying local paths or multipart syntax into the request headers.
        body.appendString(
            "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n"
        )
        body.append(audioData)
        body.appendString("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        return request
    }

    /// `joinSegments` is set for a server of the user's own, whose segment line
    /// breaks would otherwise reach the target as paragraphs.
    static func decode(data: Data, statusCode: Int, joinSegments: Bool = false) throws -> String {
        guard 200..<300 ~= statusCode else {
            throw OpenDictateError.apiError(
                OpenAIAPIErrorMessage.humanReadableMessage(from: data, statusCode: statusCode))
        }
        struct Response: Decodable { let text: String }
        guard let result = try? JSONDecoder().decode(Response.self, from: data) else {
            throw OpenDictateError.invalidResponse
        }
        let text = TranscriptText.sanitize(result.text)
        return joinSegments ? TranscriptText.joiningSegments(text) : text
    }
}
