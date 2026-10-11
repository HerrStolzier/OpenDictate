import Foundation
import Network
import OpenDictateCore
import Testing

@testable import OpenDictate

/// A one-request HTTP server on 127.0.0.1, so the real URLSession path to a
/// local model server is exercised without leaving this Mac.
private final class LoopbackServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "LoopbackServer")
    private let responseBody: Data
    private(set) var request = Data()

    init(responseBody: String) throws {
        self.responseBody = Data(responseBody.utf8)
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    func start() async throws -> UInt16 {
        listener.newConnectionHandler = { [self] connection in
            connection.start(queue: queue)
            receive(on: connection)
        }
        return try await withCheckedThrowingContinuation { continuation in
            // Resume once: the first terminal state removes the handler.
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: listener.port?.rawValue ?? 0)
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [self] data, _, done, _ in
            if let data { request.append(data) }
            if isComplete || done {
                let header =
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(responseBody.count)\r\nConnection: close\r\n\r\n"
                connection.send(
                    content: Data(header.utf8) + responseBody,
                    completion: .contentProcessed { _ in connection.cancel() })
            } else {
                receive(on: connection)
            }
        }
    }

    /// Headers received and the body length they announced.
    private var isComplete: Bool {
        guard let end = request.range(of: Data("\r\n\r\n".utf8)) else { return false }
        let head = String(decoding: request[..<end.lowerBound], as: UTF8.self).lowercased()
        let length =
            head.split(separator: "\r\n").first { $0.hasPrefix("content-length:") }
            .flatMap { Int($0.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) } ?? 0
        return request.count - end.upperBound >= length
    }

    var head: String {
        guard let end = request.range(of: Data("\r\n\r\n".utf8)) else { return "" }
        return String(decoding: request[..<end.lowerBound], as: UTF8.self)
    }

    func stop() { listener.cancel() }
}

@Suite("Local server over loopback", .serialized)
struct LocalServerTransportTests {
    private func options(port: UInt16) throws -> TranscriptionOptions {
        TranscriptionOptions(
            apiKey: "must-not-leave", model: .init(rawValue: "local-whisper"), language: "de", prompt: nil,
            translationTarget: "en", translationModel: "local-llm",
            endpoint: try #require(ServiceEndpoint("http://127.0.0.1:\(port)/v1")))
    }

    @Test func transcriptionReachesTheLocalServerWithoutAKey() async throws {
        let server = try LoopbackServer(responseBody: #"{"text":" Hallo vom lokalen Modell "}"#)
        defer { server.stop() }
        let port = try await server.start()
        let text = try await OpenAITranscriber().transcribe(audioData: Data([1, 2, 3]), options: options(port: port))
        #expect(text == "Hallo vom lokalen Modell")
        #expect(server.head.hasPrefix("POST /v1/audio/transcriptions HTTP/1.1"))
        #expect(!server.head.lowercased().contains("authorization"))
        #expect(!String(decoding: server.request, as: UTF8.self).contains("must-not-leave"))
    }

    @Test func translationReachesTheLocalServerWithoutAKey() async throws {
        let server = try LoopbackServer(
            responseBody: #"{"choices":[{"message":{"role":"assistant","content":"Hello from the local model"}}]}"#)
        defer { server.stop() }
        let port = try await server.start()
        let text = try await OpenAITranslator().translate("Hallo", into: "en", options: options(port: port))
        #expect(text == "Hello from the local model")
        #expect(server.head.hasPrefix("POST /v1/chat/completions HTTP/1.1"))
        #expect(!server.head.lowercased().contains("authorization"))
        #expect(String(decoding: server.request, as: UTF8.self).contains("local-llm"))
    }
}
