import Testing

@testable import OpenDictateCore

@Suite("Insertion delivery strategy")
struct InsertionDeliveryStrategyTests {
    @Test func terminalUsesUnicodeUnlessSecureInputOrRejectedText() {
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.apple.Terminal", role: "AXTextArea", hasWebDocument: false,
                text: "Apfel 42", isSecureInputEnabled: false) == .terminalUnicode)
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.apple.Terminal", role: "AXTextArea", hasWebDocument: false,
                text: "Apfel 42", isSecureInputEnabled: true) == .clipboardOnly(.secureInput))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.apple.Terminal", role: "AXTextArea", hasWebDocument: false,
                text: "line\nbreak", isSecureInputEnabled: false) == .clipboardOnly(.terminalRejectedText))
    }

    @Test func terminalExceptionStaysNarrow() {
        #expect(
            !InsertionDeliveryStrategy.isTerminalTarget(
                bundleIdentifier: "com.googlecode.iterm2", role: "AXTextArea", hasWebDocument: false))
        #expect(
            !InsertionDeliveryStrategy.isTerminalTarget(
                bundleIdentifier: "com.apple.Terminal", role: "AXTextField", hasWebDocument: false))
        #expect(
            !InsertionDeliveryStrategy.isTerminalTarget(
                bundleIdentifier: "com.apple.Terminal", role: "AXTextArea", hasWebDocument: true))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.googlecode.iterm2", role: "AXTextArea", hasWebDocument: false,
                text: "text", isSecureInputEnabled: false) == .nativeAX)
    }

    @Test func allowlistedEditorsNeedAWebDocument() {
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.apple.Safari", role: "AXTextArea", hasWebDocument: true,
                text: "text", isSecureInputEnabled: false) == .unicode(.isolated))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.brave.Browser", role: "AXTextArea", hasWebDocument: true,
                text: "text", isSecureInputEnabled: false) == .unicode(.trailing))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "md.obsidian", role: "AXTextArea", hasWebDocument: true,
                text: "text", isSecureInputEnabled: false) == .unicode(.grouped))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.google.Chrome", role: "AXTextArea", hasWebDocument: true,
                text: "text", isSecureInputEnabled: false) == .unicode(.isolated))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.apple.Safari", role: "AXTextArea", hasWebDocument: false,
                text: "text", isSecureInputEnabled: false) == .clipboardOnly(.unicodeRequiresWebArea))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.brave.Browser", role: "AXTextField", hasWebDocument: false,
                text: "text", isSecureInputEnabled: false) == .clipboardOnly(.unicodeRequiresWebArea))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "md.obsidian", role: "AXTextArea", hasWebDocument: false,
                text: "text", isSecureInputEnabled: false) == .clipboardOnly(.unicodeRequiresWebArea))
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.google.Chrome", role: "AXTextArea", hasWebDocument: false,
                text: "text", isSecureInputEnabled: false) == .clipboardOnly(.unicodeRequiresWebArea))
    }

    @Test func otherAppsKeepNativeAXIncludingWebEnginesOutsideTheAllowlist() {
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.apple.TextEdit", role: "AXTextArea", hasWebDocument: false,
                text: "text", isSecureInputEnabled: false) == .nativeAX)
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "org.mozilla.firefox", role: "AXTextArea", hasWebDocument: true,
                text: "text", isSecureInputEnabled: false) == .nativeAX)
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.google.Chrome.canary", role: "AXTextArea", hasWebDocument: true,
                text: "text", isSecureInputEnabled: false) == .nativeAX)
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: "com.microsoft.edgemac", role: "AXTextArea", hasWebDocument: true,
                text: "text", isSecureInputEnabled: false) == .nativeAX)
        #expect(
            InsertionDeliveryStrategy.choose(
                bundleIdentifier: nil, role: "AXTextArea", hasWebDocument: true,
                text: "text", isSecureInputEnabled: false) == .nativeAX)
    }

    @Test func lineBreakPolicyMatchesKnownEditors() {
        #expect(InsertionDeliveryStrategy.lineBreakPolicy(for: "com.apple.Safari") == .isolated)
        #expect(InsertionDeliveryStrategy.lineBreakPolicy(for: "com.google.Chrome") == .isolated)
        #expect(
            InsertionDeliveryStrategy.lineBreakPolicy(for: "com.google.Chrome")
                == InsertionDeliveryStrategy.chromeLineBreakPolicy)
        #expect(InsertionDeliveryStrategy.lineBreakPolicy(for: "com.brave.Browser") == .trailing)
        #expect(InsertionDeliveryStrategy.lineBreakPolicy(for: "md.obsidian") == .grouped)
        #expect(InsertionDeliveryStrategy.lineBreakPolicy(for: nil) == .grouped)
        #expect(InsertionDeliveryStrategy.lineBreakPolicy(for: "org.mozilla.firefox") == .grouped)
        #expect(InsertionDeliveryStrategy.lineBreakPolicy(for: "com.google.Chrome.canary") == .grouped)
    }
}
