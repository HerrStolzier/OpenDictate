import AppKit
import LocalAuthentication
import OpenDictateCore
import Security
import Testing

@testable import OpenDictate

@Suite("API key presence without credential access")
struct APIKeyPresenceTests {
    @Test func presenceQueryCannotReturnASecretOrPromptForAccess() {
        let item = KeychainItem(account: "setup-test")
        let missing = item.isMissing { query, result in
            let attributes = query as NSDictionary
            #expect(attributes[kSecReturnData as String] == nil)
            #expect(attributes[kSecValueData as String] == nil)
            let context = attributes[kSecUseAuthenticationContext as String] as? LAContext
            #expect(context?.interactionNotAllowed == true)
            #expect(result == nil)
            return errSecItemNotFound
        }
        #expect(missing)
    }

    @Test func existingOrInaccessibleItemsDoNotTriggerFirstRunSetup() {
        let item = KeychainItem(account: "setup-test")
        for status in [errSecSuccess, errSecInteractionNotAllowed, errSecAuthFailed, errSecNotAvailable] {
            let missing = item.isMissing { _, _ in status }
            #expect(!missing)
        }
    }
}

@Suite("API key setup panel")
@MainActor
struct APIKeySetupTests {
    init() { _ = NSApplication.shared }

    private func views(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { views(in: $0) }
    }

    private func primary(in panel: DictationPanel) throws -> NSButton {
        let content = try #require(panel.window?.contentView)
        return try #require(
            views(in: content).compactMap { $0 as? NSButton }
                .first { $0.accessibilityIdentifier() == "dictation-primary" })
    }

    @Test func configuredUsersKeepTheirExistingTranscriptAction() throws {
        let panel = DictationPanel()
        defer { panel.window?.close() }
        var copies = 0
        panel.onCopy = { copies += 1 }
        panel.update(outcome: .textAvailable, transcript: "Ein kontrollierter Testtext.")
        panel.updateAPIKeySetup(needsSetup: false)
        #expect(panel.display == .manual)
        try primary(in: panel).performClick(nil)
        #expect(copies == 1)
    }

    @Test func setupRefreshCannotReplaceAnActiveRecording() {
        let panel = DictationPanel()
        defer { panel.window?.close() }
        panel.update(state: .recording)
        panel.updateAPIKeySetup(needsSetup: true)
        #expect(panel.display == .recording)
    }
}
