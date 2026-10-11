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
            Self.isPlainHost(host), components.user == nil, components.password == nil,
            components.query == nil, components.fragment == nil,
            Self.hasValidPort(in: trimmed),
            let url = components.url
        else { return nil }
        switch scheme {
        case "https": break
        case "http" where Self.loopbackHosts.contains(host): break
        default: return nil
        }
        self.init(validated: url)
    }

    /// Letters, digits, dots, hyphens, underscores and the colons and
    /// brackets of an IPv6 address. A percent-escaped control character, space or separator
    /// would make the address unusable and could forge a log line.
    private static func isPlainHost(_ host: String) -> Bool {
        !host.isEmpty && host.allSatisfy { $0.isLetter || $0.isNumber || "-._:[]".contains($0) }
    }

    /// A written port must be 1 to 65535 in plain digits. Read from the text
    /// itself, because Foundation versions differ in how they parse an
    /// overflowing port. Runs after userinfo, query and fragment are rejected,
    /// so the authority holds only host and port.
    private static func hasValidPort(in address: String) -> Bool {
        guard let start = address.range(of: "://")?.upperBound else { return false }
        let authority = address[start...].prefix { $0 != "/" }
        let afterHost: Substring
        if authority.hasPrefix("[") {
            guard let close = authority.firstIndex(of: "]") else { return false }
            afterHost = authority[authority.index(after: close)...]
        } else if let colon = authority.firstIndex(of: ":") {
            afterHost = authority[colon...]
        } else {
            return true
        }
        guard !afterHost.isEmpty else { return true }
        let digits = afterHost.dropFirst()
        guard afterHost.first == ":", !digits.isEmpty, digits.count <= 5,
            digits.allSatisfy({ ("0"..."9").contains($0) }),
            let port = Int(digits)
        else { return false }
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
