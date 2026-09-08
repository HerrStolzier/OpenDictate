import Foundation
import OpenDictateCore

struct TranscriptionOptions: Sendable {
    let apiKey: String
    let model: TranscriptionModel
    let language: String?
    let prompt: String?

    static func current() throws -> Self {
        guard let key = Config.apiKey else { throw OpenDictateError.missingAPIKey }
        let model = Config.model
        guard model.isUsableForUpload else { throw OpenDictateError.invalidResponse }
        return Self(apiKey: key, model: model, language: Config.language, prompt: Config.prompt)
    }
}

struct OpenAITranscriber: Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session { self.session = session }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 120
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            self.session = URLSession(configuration: configuration)
        }
    }

    func transcribe(audioURL: URL, options: TranscriptionOptions? = nil) async throws -> String {
        try Task.checkCancellation()
        return try await transcribe(audioData: Data(contentsOf: audioURL), filename: audioURL.lastPathComponent, options: options)
    }

    func transcribe(audioData: Data, filename: String, options: TranscriptionOptions? = nil) async throws -> String {
        let options = try options ?? .current()
        let request = try Self.request(audioData: audioData, filename: filename, options: options)
        try Task.checkCancellation()
        let timing = PhaseTiming(phase: "request")
        defer { timing.finish() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw OpenDictateError.invalidResponse }
        return try Self.decode(data: data, statusCode: response.statusCode)
    }

    static func request(audioData: Data, filename: String, options: TranscriptionOptions) throws -> URLRequest {
        guard options.model.isUsableForUpload, !audioData.isEmpty,
              audioData.count <= 25 * 1_024 * 1_024 else { throw OpenDictateError.invalidResponse }
        let boundary = "OpenDictateBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(options.apiKey)", forHTTPHeaderField: "Authorization")
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
        body.appendString("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n")
        body.append(audioData)
        body.appendString("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        return request
    }

    static func decode(data: Data, statusCode: Int) throws -> String {
        guard 200..<300 ~= statusCode else {
            throw OpenDictateError.apiError(OpenAIAPIErrorMessage.humanReadableMessage(from: data, statusCode: statusCode))
        }
        struct Response: Decodable { let text: String }
        guard let result = try? JSONDecoder().decode(Response.self, from: data) else {
            throw OpenDictateError.invalidResponse
        }
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
