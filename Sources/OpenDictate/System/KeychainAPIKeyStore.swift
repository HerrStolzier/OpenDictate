import Foundation
import OpenDictateCore
import Security

enum KeychainAPIKeyStore {
    private static let item = KeychainItem(account: "OPENAI_API_KEY")

    static func read() -> String? {
        guard
            let data = item.readData(),
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else {
            return nil
        }

        return key
    }

    static func save(_ key: String) throws {
        let data = Data(key.utf8)
        let updateStatus = item.update(with: data)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw OpenDictateError.keychainStatus(updateStatus)
        }

        let addStatus = item.add(data)
        guard addStatus == errSecSuccess else {
            throw OpenDictateError.keychainStatus(addStatus)
        }
    }
}
