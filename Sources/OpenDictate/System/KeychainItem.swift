import Foundation
import Security

/// Small wrapper around the shared generic-password boilerplate. Individual
/// stores still own their account name and update/create policy.
struct KeychainItem {
    private static let service = "OpenDictate"

    let account: String

    func readData() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    func add(_ data: Data, accessible: CFString? = nil) -> OSStatus {
        var query = baseQuery
        query[kSecValueData as String] = data
        if let accessible {
            query[kSecAttrAccessible as String] = accessible
        }
        return SecItemAdd(query as CFDictionary, nil)
    }

    func delete() -> OSStatus {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]
    }
}
