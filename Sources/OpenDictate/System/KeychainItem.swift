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
        matching: ((CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus)? = nil
    ) -> Bool {
        presenceStatus(matching: matching) == errSecItemNotFound
    }

    func presenceStatus(
        matching: ((CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus)? = nil
    ) -> OSStatus {
        if matching == nil, KeychainBridge.isActive {
            return KeychainBridge.perform(.presence, account: account).0
        }
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        return (matching ?? SecItemCopyMatching)(query as CFDictionary, nil)
    }

    func readData() -> Data? {
        guard case .data(let data) = readResult() else { return nil }
        return data
    }

    func readResult(
        matching: ((CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus)? = nil
    ) -> ReadResult {
        if matching == nil, KeychainBridge.isActive {
            let (status, data) = KeychainBridge.perform(.read, account: account)
            if status == errSecItemNotFound { return .missing }
            guard status == errSecSuccess else { return .failure(status) }
            guard let data else { return .failure(errSecDecode) }
            return .data(data)
        }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = (matching ?? SecItemCopyMatching)(query as CFDictionary, &result)
        if status == errSecItemNotFound { return .missing }
        guard status == errSecSuccess else { return .failure(status) }
        guard let data = result as? Data else { return .failure(errSecDecode) }
        return .data(data)
    }

    func update(
        _ data: Data,
        updating: ((CFDictionary, CFDictionary) -> OSStatus)? = nil
    ) -> OSStatus {
        if updating == nil, KeychainBridge.isActive {
            return KeychainBridge.perform(.update, account: account, data: data).0
        }
        return (updating ?? SecItemUpdate)(
            baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    }

    func add(
        _ data: Data,
        accessible: CFString? = nil,
        adding: ((CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus)? = nil
    ) -> OSStatus {
        if adding == nil, KeychainBridge.isActive {
            return KeychainBridge.perform(.add, account: account, data: data).0
        }
        var query = baseQuery
        query[kSecValueData as String] = data
        if let accessible {
            query[kSecAttrAccessible as String] = accessible
        }
        return (adding ?? SecItemAdd)(query as CFDictionary, nil)
    }

    func delete() -> OSStatus {
        if KeychainBridge.isActive {
            return KeychainBridge.perform(.delete, account: account).0
        }
        return SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]
    }
}
