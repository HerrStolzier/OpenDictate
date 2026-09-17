import Foundation
import OpenDictateCore
import Security
import Testing

@testable import OpenDictate

@Suite("API key replacement without deleting the working credential")
struct KeychainAPIKeyStoreTests {
    private let canonical = "OPENAI_API_KEY_APP"
    private let legacy = "OPENAI_API_KEY"
    private let previous = Data("previous synthetic value".utf8)
    private let replacement = "replacement synthetic value"

    @Test func migratingLegacyCreatesTheReplacementBeforeDeletingTheOldItem() throws {
        let store = FakeKeychain(items: [legacy: previous])
        let result = try KeychainAPIKeyStore.save(replacement, using: store.operations)

        #expect(result == .saved)
        #expect(store.items[canonical] == Data(replacement.utf8))
        #expect(store.items[legacy] == nil)
        #expect(store.events == ["update:\(canonical)", "add:\(canonical)", "delete:\(legacy)"])
    }

    @Test func failedCreationLeavesTheLegacyCredentialUntouched() {
        for status in [errSecNotAvailable, errSecAuthFailed, errSecInteractionNotAllowed] {
            let store = FakeKeychain(items: [legacy: previous])
            store.addFailure = status
            expectSaveFailure(status, in: store)

            #expect(store.items == [legacy: previous])
            #expect(store.events == ["update:\(canonical)", "add:\(canonical)"])
        }
    }

    @Test func failedUpdatePreservesBothExistingCredentials() {
        let store = FakeKeychain(items: [canonical: previous, legacy: previous])
        store.updateFailure = errSecAuthFailed
        expectSaveFailure(errSecAuthFailed, in: store)

        #expect(store.items == [canonical: previous, legacy: previous])
        #expect(store.events == ["update:\(canonical)"])
    }

    @Test func existingCanonicalCredentialIsUpdatedWithoutRecreatingItsACL() throws {
        let store = FakeKeychain(items: [canonical: previous])
        let result = try KeychainAPIKeyStore.save(replacement, using: store.operations)

        #expect(result == .saved)
        #expect(store.items == [canonical: Data(replacement.utf8)])
        #expect(store.events == ["update:\(canonical)", "delete:\(legacy)"])
    }

    @Test func failedLegacyCleanupReportsThatTheReplacementWasSaved() throws {
        let store = FakeKeychain(items: [legacy: previous])
        store.deleteFailure = errSecInteractionNotAllowed
        let result = try KeychainAPIKeyStore.save(replacement, using: store.operations)

        #expect(result == .savedWithLegacyCleanupPending(errSecInteractionNotAllowed))
        #expect(store.items[canonical] == Data(replacement.utf8))
        #expect(store.items[legacy] == previous)
        store.events = []
        #expect(KeychainAPIKeyStore.read(using: store.operations) == replacement)
        #expect(store.events == ["read:\(canonical)"])
    }

    @Test func aCompetingCreateIsNotOverwrittenOrDeleted() {
        let winner = Data("another synthetic value".utf8)
        let store = FakeKeychain(items: [legacy: previous])
        store.competingCreate = winner
        expectSaveFailure(errSecDuplicateItem, in: store)

        #expect(store.items == [canonical: winner, legacy: previous])
        #expect(store.events == ["update:\(canonical)", "add:\(canonical)"])
    }

    @Test func onlyConfirmedCanonicalAbsenceAllowsTheLegacyRead() {
        let store = FakeKeychain(items: [legacy: previous])
        #expect(KeychainAPIKeyStore.read(using: store.operations) == String(data: previous, encoding: .utf8))
        #expect(store.events == ["read:\(canonical)", "read:\(legacy)"])

        for status in [errSecAuthFailed, errSecInteractionNotAllowed, errSecNotAvailable, errSecDecode] {
            store.events = []
            store.readFailures[canonical] = status
            #expect(KeychainAPIKeyStore.read(using: store.operations) == nil)
            #expect(store.events == ["read:\(canonical)"])
        }
    }

    @Test func emptyOrMalformedCanonicalDataDoesNotUseAnOlderCredential() {
        for data in [Data(), Data([0xFF])] {
            let store = FakeKeychain(items: [canonical: data, legacy: previous])
            #expect(KeychainAPIKeyStore.read(using: store.operations) == nil)
            #expect(store.events == ["read:\(canonical)"])
        }
    }

    @Test func setupRequiresConfirmedAbsenceOfBothAccountsWithoutReadingSecrets() {
        let empty = FakeKeychain()
        #expect(KeychainAPIKeyStore.needsSetup(using: empty.operations))
        #expect(empty.events == ["presence:\(canonical)", "presence:\(legacy)"])

        let migrated = FakeKeychain(items: [canonical: previous])
        #expect(!KeychainAPIKeyStore.needsSetup(using: migrated.operations))
        #expect(migrated.events == ["presence:\(canonical)"])

        let existingLegacy = FakeKeychain(items: [legacy: previous])
        #expect(!KeychainAPIKeyStore.needsSetup(using: existingLegacy.operations))
        #expect(existingLegacy.events == ["presence:\(canonical)", "presence:\(legacy)"])

        for account in [canonical, legacy] {
            for status in [errSecAuthFailed, errSecInteractionNotAllowed, errSecNotAvailable] {
                let inaccessible = FakeKeychain()
                inaccessible.presenceFailures[account] = status
                #expect(!KeychainAPIKeyStore.needsSetup(using: inaccessible.operations))
                let expected = account == canonical ? ["presence:\(canonical)"] : empty.events
                #expect(inaccessible.events == expected)
            }
        }
    }

    private func expectSaveFailure(_ expected: OSStatus, in store: FakeKeychain) {
        do {
            try KeychainAPIKeyStore.save(replacement, using: store.operations)
            Issue.record("Expected the simulated Keychain write to fail.")
        } catch OpenDictateError.keychainStatus(let status) {
            #expect(status == expected)
        } catch {
            Issue.record("Unexpected error type from simulated Keychain write.")
        }
    }
}

@Suite("Keychain item status and write boundaries")
struct KeychainItemStatusTests {
    @Test func readDistinguishesAbsenceAccessFailureAndInvalidResultData() {
        let item = KeychainItem(account: "synthetic-account")
        #expect(item.readResult { _, _ in errSecItemNotFound } == .missing)
        #expect(item.readResult { _, _ in errSecAuthFailed } == .failure(errSecAuthFailed))
        #expect(item.readResult { _, _ in errSecSuccess } == .failure(errSecDecode))
        let data = Data("synthetic value".utf8)
        let result = item.readResult { query, output in
            #expect((query as NSDictionary)[kSecReturnData as String] as? Bool == true)
            output?.pointee = data as CFData
            return errSecSuccess
        }
        #expect(result == .data(data))
    }

    @Test func writesKeepTheAccountAndOnlyUpdateTheData() {
        let item = KeychainItem(account: "synthetic-account")
        let data = Data("synthetic value".utf8)
        let status = item.update(data) { query, attributes in
            let query = query as NSDictionary
            #expect(query[kSecAttrAccount as String] as? String == item.account)
            #expect(query[kSecAttrService as String] as? String == "OpenDictate")
            #expect(query[kSecValueData as String] == nil)
            #expect(query[kSecReturnData as String] == nil)
            #expect((attributes as NSDictionary) as? [String: Data] == [kSecValueData as String: data])
            return errSecSuccess
        }
        #expect(status == errSecSuccess)

        let addStatus = item.add(data) { query, output in
            let query = query as NSDictionary
            #expect(query[kSecAttrAccount as String] as? String == item.account)
            #expect(query[kSecValueData as String] as? Data == data)
            #expect(query[kSecAttrAccess as String] == nil)
            #expect(query[kSecAttrAccessible as String] == nil)
            #expect(output == nil)
            return errSecSuccess
        }
        #expect(addStatus == errSecSuccess)
    }
}

private final class FakeKeychain {
    var items: [String: Data]
    var events: [String] = []
    var readFailures: [String: OSStatus] = [:]
    var presenceFailures: [String: OSStatus] = [:]
    var updateFailure: OSStatus?
    var addFailure: OSStatus?
    var deleteFailure: OSStatus?
    var competingCreate: Data?

    init(items: [String: Data] = [:]) { self.items = items }

    var operations: KeychainAPIKeyStore.Operations {
        KeychainAPIKeyStore.Operations(
            read: { item in
                self.events.append("read:\(item.account)")
                if let failure = self.readFailures[item.account] { return .failure(failure) }
                return self.items[item.account].map(KeychainItem.ReadResult.data) ?? .missing
            },
            presence: { item in
                self.events.append("presence:\(item.account)")
                if let failure = self.presenceFailures[item.account] { return failure }
                return self.items[item.account] == nil ? errSecItemNotFound : errSecSuccess
            },
            update: { item, data in
                self.events.append("update:\(item.account)")
                if let failure = self.updateFailure { return failure }
                guard self.items[item.account] != nil else { return errSecItemNotFound }
                self.items[item.account] = data
                return errSecSuccess
            },
            add: { item, data in
                self.events.append("add:\(item.account)")
                if let winner = self.competingCreate { self.items[item.account] = winner }
                if let failure = self.addFailure { return failure }
                guard self.items[item.account] == nil else { return errSecDuplicateItem }
                self.items[item.account] = data
                return errSecSuccess
            },
            delete: { item in
                self.events.append("delete:\(item.account)")
                if let failure = self.deleteFailure { return failure }
                return self.items.removeValue(forKey: item.account) == nil ? errSecItemNotFound : errSecSuccess
            })
    }
}
