import CryptoKit
import Foundation
import OpenDictateCore
import Security

/// A device-local Keychain secret authenticates failed recordings across app
/// launches. Directory ownership alone cannot distinguish an app-created file
/// from one planted by another process running as the same user.
enum RecordingAuthenticationKeyStore {
    private static let service = "OpenDictate"
    private static let account = "FAILED_RECORDING_AUTH_KEY"

    static func read() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              data.count == 32
        else { return nil }
        return SymmetricKey(data: data)
    }

    static func readOrCreate() throws -> SymmetricKey {
        if let existing = read() { return existing }

        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw OpenDictateError.keychainStatus(status)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: bytes
        ]
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            if addStatus == errSecDuplicateItem, let existing = read() { return existing }
            throw OpenDictateError.keychainStatus(addStatus)
        }
        return SymmetricKey(data: bytes)
    }
}
