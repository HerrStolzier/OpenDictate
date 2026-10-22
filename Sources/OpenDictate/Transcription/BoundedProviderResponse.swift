import Foundation
import OpenDictateCore

/// Read provider responses incrementally. `data(for:)` buffers an unbounded
/// body before the caller can inspect it, including error responses.
enum BoundedProviderResponse {
    static let maximumBytes = 1_024 * 1_024

    static func load(_ request: URLRequest, using session: URLSession) async throws -> (Data, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse,
            response.expectedContentLength <= maximumBytes
        else { throw OpenDictateError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw OpenDictateError.invalidResponse }
            data.append(byte)
        }
        return (data, response)
    }
}
