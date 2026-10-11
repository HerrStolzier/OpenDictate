import CryptoKit
import Foundation
import Security

/// Secrets in the iPhone's Keychain only. "After first unlock" lets a
/// dictation started from the lock screen read them; "this device only" keeps
/// them out of backups and off other devices.
enum KeychainStore {
    private static let service = "app.opendictate.ios"
    /// The OpenAI API key.
    private static let apiKeyAccount = "openai-api-key"
    /// The key that tags kept recordings (`PendingRecordings`).
    private static let recordingKeyAccount = "recording-authentication-key"

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func read(_ account: String) -> (data: Data?, status: OSStatus) {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        return (status == errSecSuccess ? result as? Data : nil, status)
    }

    private static func write(_ data: Data, to account: String) -> Bool {
        SecItemDelete(query(account) as CFDictionary)
        var item = query(account)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func apiKey() -> String? {
        guard let data = read(apiKeyAccount).data, let key = String(data: data, encoding: .utf8), !key.isEmpty else {
            return nil
        }
        return key
    }

    /// Replaces the stored key. Returns false when the Keychain refused it.
    static func save(apiKey: String) -> Bool {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        return write(Data(key.utf8), to: apiKeyAccount)
    }

    static func deleteAPIKey() {
        SecItemDelete(query(apiKeyAccount) as CFDictionary)
    }

    /// The recording key. `create` makes one only when none exists yet, never
    /// after a read error, so a passing Keychain problem cannot replace the key
    /// and void every tag. nil means recordings are kept but not offered for
    /// "Send again".
    static func recordingKey(create: Bool) -> SymmetricKey? {
        let stored = read(recordingKeyAccount)
        if let data = stored.data, data.count == 32 { return SymmetricKey(data: data) }
        guard create, stored.status == errSecItemNotFound else { return nil }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        return write(data, to: recordingKeyAccount) ? key : nil
    }
}
