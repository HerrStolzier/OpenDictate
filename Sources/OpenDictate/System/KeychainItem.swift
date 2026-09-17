import Foundation
import LocalAuthentication
import Security

/// Small wrapper around the shared generic-password boilerplate. Individual
/// stores still own their account name and update/create policy.
struct KeychainItem {
    enum ReadResult: Equatable {
        case data(Data)
        case missing
        case failure(OSStatus)
    }

    private static let service = "OpenDictate"

    let account: String

    /// Check only for absence, without returning secret data or requesting UI.
    /// A locked or inaccessible existing item must not trigger first-run setup.
    func isMissing(
        matching: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemCopyMatching
    ) -> Bool {
        presenceStatus(matching: matching) == errSecItemNotFound
    }

    func presenceStatus(
        matching: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemCopyMatching
    ) -> OSStatus {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        return matching(query as CFDictionary, nil)
    }

    func readData() -> Data? {
        guard case .data(let data) = readResult() else { return nil }
        return data
    }

    func readResult(
        matching: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemCopyMatching
    ) -> ReadResult {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = matching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return .missing }
        guard status == errSecSuccess else { return .failure(status) }
        guard let data = result as? Data else { return .failure(errSecDecode) }
        return .data(data)
    }

    func update(
        _ data: Data,
        updating: (CFDictionary, CFDictionary) -> OSStatus = SecItemUpdate
    ) -> OSStatus {
        updating(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    }

    func add(
        _ data: Data,
        accessible: CFString? = nil,
        adding: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemAdd
    ) -> OSStatus {
        var query = baseQuery
        query[kSecValueData as String] = data
        if let accessible {
            query[kSecAttrAccessible as String] = accessible
        }
        return adding(query as CFDictionary, nil)
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
