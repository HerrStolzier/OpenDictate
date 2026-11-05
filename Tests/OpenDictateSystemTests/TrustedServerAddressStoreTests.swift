import Foundation
import OpenDictateCore
import Security
import Testing

@testable import OpenDictate

@Suite("Trusted server address")
struct TrustedServerAddressStoreTests {
    @Test func onlyTheSavedAddressCanReceiveAudioAndTheKey() throws {
        let keychain = FakeTrustedServerKeychain()
        let approved = try #require(ServiceEndpoint("https://trusted.example/v1"))
        let changedPreference = try #require(ServiceEndpoint("https://changed.example/v1"))

        #expect(!TrustedServerAddressStore.isApproved(approved, using: keychain.operations))
        try TrustedServerAddressStore.save(approved, using: keychain.operations)
        #expect(TrustedServerAddressStore.isApproved(approved, using: keychain.operations))
        #expect(!TrustedServerAddressStore.isApproved(changedPreference, using: keychain.operations))
        try TrustedServerAddressStore.remove(using: keychain.operations)
        #expect(!TrustedServerAddressStore.isApproved(approved, using: keychain.operations))
    }

    @Test func keychainFailureDoesNotApproveAnAddress() throws {
        let keychain = FakeTrustedServerKeychain()
        let endpoint = try #require(ServiceEndpoint("https://trusted.example/v1"))
        keychain.failure = errSecAuthFailed
        #expect(!TrustedServerAddressStore.isApproved(endpoint, using: keychain.operations))
        #expect(throws: OpenDictateError.self) {
            try TrustedServerAddressStore.save(endpoint, using: keychain.operations)
        }
    }
}

private final class FakeTrustedServerKeychain {
    var data: Data?
    var failure: OSStatus?

    var operations: TrustedServerAddressStore.Operations {
        TrustedServerAddressStore.Operations(
            read: { _ in
                if let failure = self.failure { return .failure(failure) }
                return self.data.map(KeychainItem.ReadResult.data) ?? .missing
            },
            update: { _, data in
                if let failure = self.failure { return failure }
                guard self.data != nil else { return errSecItemNotFound }
                self.data = data
                return errSecSuccess
            },
            add: { _, data in
                if let failure = self.failure { return failure }
                guard self.data == nil else { return errSecDuplicateItem }
                self.data = data
                return errSecSuccess
            },
            delete: { _ in
                if let failure = self.failure { return failure }
                guard self.data != nil else { return errSecItemNotFound }
                self.data = nil
                return errSecSuccess
            })
    }
}
