import Foundation

/// Rules for the API key dialog. The stored key is never put back into a text
/// field; the dialog shows a short hint instead, and an empty field keeps it.
public enum APIKeyEntry {
    public enum Decision: Equatable, Sendable {
        /// Nothing entered while a key is stored: leave the stored key alone.
        case keep
        /// Nothing entered and nothing stored.
        case empty
        case save(String)
    }

    /// What the dialog knows about the stored key. An item that exists but
    /// could not be read is never treated as missing.
    public enum Stored: Equatable, Sendable {
        case missing
        case readable(hint: String)
        case unreadable

        public var hint: String? {
            guard case .readable(let hint) = self else { return nil }
            return hint
        }
    }

    /// Keys shorter than this show no trailing characters at all.
    static let minimumLengthForSuffix = 12

    /// "sk-…abcd" for an OpenAI key: enough to recognise which key is stored,
    /// too little to use it.
    public static func maskedHint(for key: String) -> String {
        let prefix = key.hasPrefix("sk-") ? "sk-" : ""
        guard key.count >= minimumLengthForSuffix else { return prefix + "…" }
        return prefix + "…" + key.suffix(4)
    }

    public static func decision(for entered: String, hasStoredKey: Bool) -> Decision {
        let key = entered.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.isEmpty else { return .save(key) }
        return hasStoredKey ? .keep : .empty
    }
}
