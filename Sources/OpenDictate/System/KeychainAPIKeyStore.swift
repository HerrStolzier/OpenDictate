import Foundation
import OpenDictateCore
import Security

enum KeychainAPIKeyStore {
    enum SaveResult: Equatable {
        case saved
        case savedWithLegacyCleanupPending(OSStatus)
    }

    struct Operations {
        var read: (KeychainItem) -> KeychainItem.ReadResult
        var presence: (KeychainItem) -> OSStatus
        var update: (KeychainItem, Data) -> OSStatus
        var add: (KeychainItem, Data) -> OSStatus
        var delete: (KeychainItem) -> OSStatus

        static var live: Self {
            Self(
                read: { $0.readResult() },
                presence: { $0.presenceStatus() },
                update: { $0.update($1) },
                add: { $0.add($1) },
                delete: { $0.delete() })
        }
    }

    private static let item = KeychainItem(account: "OPENAI_API_KEY_APP")
    private static let legacyItem = KeychainItem(account: "OPENAI_API_KEY")

    static var needsSetup: Bool { needsSetup(using: .live) }

    static func needsSetup(using operations: Operations) -> Bool {
        guard operations.presence(item) == errSecItemNotFound else { return false }
        return operations.presence(legacyItem) == errSecItemNotFound
    }

    static func read(using operations: Operations = .live) -> String? {
        let result = operations.read(item)
        let selectedResult: KeychainItem.ReadResult
        if case .missing = result {
            selectedResult = operations.read(legacyItem)
        } else {
            selectedResult = result
        }

        guard case .data(let data) = selectedResult,
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String, using operations: Operations = .live) throws -> SaveResult {
        let data = Data(key.utf8)
        var status = operations.update(item, data)
        if status == errSecItemNotFound {
            // A distinct account creates the app's default ACL instead of
            // inheriting a legacy item that may still trust /usr/bin/security.
            status = operations.add(item, data)
        }
        guard status == errSecSuccess else { throw OpenDictateError.keychainStatus(status) }

        // Never delete a working credential before its replacement is stored.
        // An add race is a normal failure above; it must not overwrite its winner.
        let cleanupStatus = operations.delete(legacyItem)
        if cleanupStatus == errSecSuccess || cleanupStatus == errSecItemNotFound { return .saved }
        return .savedWithLegacyCleanupPending(cleanupStatus)
    }
}
