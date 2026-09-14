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
        let previousData = item.readData()
        let deleteStatus = item.delete()
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw OpenDictateError.keychainStatus(deleteStatus)
        }

        let addStatus = item.add(data)
        if addStatus == errSecSuccess {
            return
        }

        // Recreate under the app instead of updating a legacy item whose ACL may
        // still trust /usr/bin/security. Preserve the previous secret if the new
        // write fails after deletion.
        if let previousData {
            let restoreStatus = item.add(previousData)
            guard restoreStatus == errSecSuccess else {
                throw OpenDictateError.keychainStatus(restoreStatus)
            }
        }
        throw OpenDictateError.keychainStatus(addStatus)
    }
}
