import Foundation

/// Base address of the transcription and translation service. Any server that
/// speaks the OpenAI request format works, including a local one. Only the
/// address changes; there is no provider list and no auto-detection.
public struct ServiceEndpoint: Sendable, Equatable {
    public static let openAI = ServiceEndpoint(validated: URL(string: "https://api.openai.com/v1")!)

    /// Normalized base URL without a trailing slash, for example
    /// `http://127.0.0.1:8080/v1`.
    public let baseURL: URL

    private init(validated baseURL: URL) { self.baseURL = baseURL }

    /// Accepts `https://` for any host and `http://` only for this Mac, so
    /// audio and an API key never travel unencrypted over a network.
    /// Credentials, query and fragment are rejected.
    public init?(_ text: String) {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard trimmed.count <= 2_048, let components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(), let host = components.host?.lowercased(),
            !host.isEmpty, components.user == nil, components.password == nil,
            components.query == nil, components.fragment == nil,
            Self.hasValidPort(components),
            let url = components.url
        else { return nil }
        switch scheme {
        case "https": break
        case "http" where Self.loopbackHosts.contains(host): break
        default: return nil
        }
        self.init(validated: url)
    }

    /// A written port must parse and be a usable TCP port; an overflowing
    /// number parses as no port at all, so it is rejected as well.
    private static func hasValidPort(_ components: URLComponents) -> Bool {
        guard components.rangeOfPort != nil else { return true }
        guard let port = components.port else { return false }
        return (1...65_535).contains(port)
    }

    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]

    /// True for a server on this Mac. Such a server gets no API key.
    public var isLoopback: Bool {
        Self.loopbackHosts.contains(baseURL.host?.lowercased() ?? "")
    }

    public var isOpenAI: Bool { self == .openAI }

    /// Host only, safe for the log.
    public var host: String { baseURL.host ?? "" }

    public var transcriptionURL: URL { baseURL.appendingPathComponent("audio/transcriptions") }
    public var chatCompletionsURL: URL { baseURL.appendingPathComponent("chat/completions") }
}

/// Model identifiers sent as plain field values. Local servers use IDs such
/// as `Systran/faster-whisper-small` or `llama3:8b`, so slashes and colons
/// are allowed; whitespace, quotes and control characters are not.
public enum ModelName {
    public static func isValid(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 128 && !name.contains("..")
            && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-._/:".contains($0)) }
    }
}
