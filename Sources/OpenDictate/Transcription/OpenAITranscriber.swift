import Foundation

struct OpenAITranscriber {
    func transcribe(audioURL: URL) async throws -> String {
        guard let apiKey = Config.apiKey else {
            throw OpenDictateError.missingAPIKey
        }

        AppLog.write("Uploading audio to OpenAI. model=\(Config.model)")
        let boundary = "OpenDictateBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendField(name: "model", value: Config.model, boundary: boundary, body: &body)
        appendField(name: "response_format", value: "text", boundary: boundary, body: &body)

        if let language = Config.language, !language.isEmpty {
            appendField(name: "language", value: language, boundary: boundary, body: &body)
        }

        if let prompt = Config.prompt, !prompt.isEmpty {
            appendField(name: "prompt", value: prompt, boundary: boundary, body: &body)
        }

        let audioData = try Data(contentsOf: audioURL)
        appendFile(
            name: "file",
            filename: audioURL.lastPathComponent,
            mimeType: "audio/m4a",
            data: audioData,
            boundary: boundary,
            body: &body
        )
        body.appendString("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenDictateError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = OpenAIAPIErrorMessage.humanReadableMessage(from: data, statusCode: httpResponse.statusCode)
            AppLog.write("OpenAI API returned HTTP \(httpResponse.statusCode): \(message.replacingOccurrences(of: "\n", with: " "))")
            throw OpenDictateError.apiError(message)
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func appendField(name: String, value: String, boundary: String, body: inout Data) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.appendString("\(value)\r\n")
    }

    private func appendFile(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String,
        body: inout Data
    ) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
    }
}
