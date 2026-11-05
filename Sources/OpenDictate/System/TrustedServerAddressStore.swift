import Foundation
import OpenDictateCore
import Security

/// A mutable preference must not choose where a Keychain API key and audio go.
/// Only an address saved through the app's settings dialog is approved here.
enum TrustedServerAddressStore {
    struct Operations {
        var read: (KeychainItem) -> KeychainItem.ReadResult
        var update: (KeychainItem, Data) -> OSStatus
        var add: (KeychainItem, Data) -> OSStatus
        var delete: (KeychainItem) -> OSStatus

        static var live: Self {
            Self(
                read: { $0.readResult() },
                update: { $0.update($1) },
                add: { $0.add($1) },
                delete: { $0.delete() })
        }
    }

    private static let item = KeychainItem(account: "TRUSTED_SERVER_ADDRESS")

    static func isApproved(_ endpoint: ServiceEndpoint, using operations: Operations = .live) -> Bool {
        guard case .data(let data) = operations.read(item),
            let address = String(data: data, encoding: .utf8),
            let approved = ServiceEndpoint(address)
        else { return false }
        return approved == endpoint
    }

    static func save(_ endpoint: ServiceEndpoint, using operations: Operations = .live) throws {
        let data = Data(endpoint.baseURL.absoluteString.utf8)
        var status = operations.update(item, data)
        if status == errSecItemNotFound { status = operations.add(item, data) }
        guard status == errSecSuccess else { throw OpenDictateError.keychainStatus(status) }
    }

    static func remove(using operations: Operations = .live) throws {
        let status = operations.delete(item)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw OpenDictateError.keychainStatus(status)
        }
    }
}
