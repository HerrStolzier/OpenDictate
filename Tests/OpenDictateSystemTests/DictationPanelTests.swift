import AppKit
import OpenDictateCore
import Testing

@testable import OpenDictate

@Suite("Delivery presentation without showing a window")
@MainActor
struct DictationPanelTests {
    init() { _ = NSApplication.shared }

    private func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }

    private func expectHidden(_ panel: DictationPanel, keyWindow: NSWindow?) {
        #expect(panel.window?.isVisible == false)
        #expect(panel.window?.isKeyWindow == false)
        #expect(NSApp.keyWindow === keyWindow)
    }

    @Test func fullDictationCycleStaysHiddenAndRetainsItsTranscript() throws {
        let outcomes: [DictationOutcome] = [
            .textAvailable, .deliveryUnconfirmed,
            .deliveryUncertain, .failed, .cancelled
        ]
        for outcome in outcomes {
            let panel = DictationPanel()
            defer { panel.close() }
            let keyWindow = NSApp.keyWindow
            let text = "Das vollständige Ergebnis.\nGrüße 🍏 und e\u{301}."
            panel.update(state: .recording)
            expectHidden(panel, keyWindow: keyWindow)
            panel.updateRecording(elapsed: 83, level: -25)
            expectHidden(panel, keyWindow: keyWindow)
            panel.updateRecording(elapsed: 89, level: -25)
            expectHidden(panel, keyWindow: keyWindow)
            panel.update(state: .processing)
            expectHidden(panel, keyWindow: keyWindow)
            panel.update(state: .delivering)
            expectHidden(panel, keyWindow: keyWindow)
            panel.update(outcome: outcome, transcript: text)
            expectHidden(panel, keyWindow: keyWindow)
            panel.update(state: .idle)
            expectHidden(panel, keyWindow: keyWindow)

            let content = try #require(panel.window?.contentView)
            let textView = try #require(descendants(of: content).compactMap { $0 as? NSTextView }.first)
            #expect(textView.string == text)
            #expect(textView.isSelectable)
        }
    }

    @Test func permissionFailureKeepsItsMessageAndRecoveryActionWithoutOpening() throws {
        let panel = DictationPanel()
        defer { panel.close() }
        let keyWindow = NSApp.keyWindow
        let message = "Mikrofonzugriff fehlt. Öffne die Systemeinstellungen und erlaube den Zugriff."
        var recoveryRequests = 0
        panel.onRecovery = { recoveryRequests += 1 }
        panel.updateFailure(message)
        expectHidden(panel, keyWindow: keyWindow)

        let content = try #require(panel.window?.contentView)
        let views = descendants(of: content)
        let labels = views.compactMap { $0 as? NSTextField }.map(\.stringValue)
        let primary = try #require(
            views.compactMap { $0 as? NSButton }.first { $0.accessibilityIdentifier() == "dictation-primary" })
        #expect(panel.display == .failure)
        #expect(labels.contains(message))
        #expect(primary.isEnabled && !primary.isHidden)
        primary.performClick(nil)
        #expect(recoveryRequests == 1)
        expectHidden(panel, keyWindow: keyWindow)
    }

    @Test func setupUpdatesKeepTheirActionAvailableWithoutOpeningOrRecording() throws {
        let panel = DictationPanel()
        defer { panel.close() }
        let keyWindow = NSApp.keyWindow
        var setupRequests = 0
        var recordings = 0
        panel.onSetup = { setupRequests += 1 }
        panel.onRecord = { recordings += 1 }
        panel.updateAPIKeySetup(needsSetup: true)
        expectHidden(panel, keyWindow: keyWindow)

        let content = try #require(panel.window?.contentView)
        let views = descendants(of: content)
        let primary = try #require(
            views.compactMap { $0 as? NSButton }.first { $0.accessibilityIdentifier() == "dictation-primary" })
        #expect(primary.isEnabled && !primary.isHidden)
        primary.performClick(nil)
        #expect(setupRequests == 1 && recordings == 0)
        expectHidden(panel, keyWindow: keyWindow)

        let message = "Der Schlüssel konnte nicht gespeichert werden. Versuche es erneut."
        panel.updateAPIKeySetup(needsSetup: true, message: message)
        #expect(views.compactMap { $0 as? NSTextField }.map(\.stringValue).contains(message))
        #expect(primary.title == "API-Schlüssel einrichten")
        expectHidden(panel, keyWindow: keyWindow)

        panel.updateAPIKeySetup(needsSetup: false)
        #expect(panel.display == .ready)
        #expect(primary.title == "Aufnahme starten")
        #expect(recordings == 0)
        expectHidden(panel, keyWindow: keyWindow)
    }

    @Test func uncertainInsertionShowsCompleteTextAndCopyWithoutClaimingNoInsertion() throws {
        let panel = DictationPanel()
        defer { panel.close() }
        let text = "Vollständiger Text.\nGrüße 🍏 und e\u{301}."
        var copied = 0
        panel.onCopy = { copied += 1 }
        panel.update(state: .delivering)
        panel.update(outcome: .deliveryUncertain, transcript: text)
        panel.update(state: .idle)

        let content = try #require(panel.window?.contentView)
        let views = descendants(of: content)
        let textView = try #require(views.compactMap { $0 as? NSTextView }.first)
        let scroll = try #require(views.compactMap { $0 as? NSScrollView }.first)
        let copy = try #require(views.compactMap { $0 as? NSButton }.first { $0.title == "Text kopieren" })
        let labels = views.compactMap { $0 as? NSTextField }.map(\.stringValue).joined(separator: "\n")
        #expect(panel.display == .unconfirmed)
        #expect(panel.window?.isVisible == false)
        #expect(textView.string == text)
        #expect(textView.isSelectable)
        #expect(!scroll.isHidden)
        #expect(copy.isEnabled && !copy.isHidden)
        #expect(labels.contains("Möglicherweise"))
        #expect(labels.contains("Prüfe es vor manuellem Einfügen"))
        #expect(!labels.contains("Nicht automatisch eingefügt"))
        #expect(!labels.contains("Text eingefügt."))
        copy.performClick(nil)
        #expect(copied == 1)
    }

    @Test func completeSubmissionStaysUnconfirmedAndTextRemainsAccessible() throws {
        let panel = DictationPanel()
        defer { panel.close() }
        panel.update(outcome: .deliveryUnconfirmed, transcript: "Vollständiger Text")
        let content = try #require(panel.window?.contentView)
        let views = descendants(of: content)
        let reveal = try #require(views.compactMap { $0 as? NSButton }.first { $0.title == "Text ansehen" })
        let scroll = try #require(views.compactMap { $0 as? NSScrollView }.first)
        let textView = try #require(views.compactMap { $0 as? NSTextView }.first)
        let labels = views.compactMap { $0 as? NSTextField }.map(\.stringValue).joined(separator: "\n")
        #expect(panel.display == .unconfirmed)
        #expect(labels.contains("Prüfe den Text im Zielprogramm"))
        #expect(!labels.contains("Text eingefügt."))
        reveal.performClick(nil)
        #expect(!scroll.isHidden)
        #expect(textView.string == "Vollständiger Text")
        #expect(reveal.title == "Text kopieren")
    }

    @Test func noSubmissionShowsCompleteTranscriptForManualCopy() throws {
        let panel = DictationPanel()
        defer { panel.close() }
        panel.update(outcome: .textAvailable, transcript: "Vollständiger Text")
        let content = try #require(panel.window?.contentView)
        let views = descendants(of: content)
        let scroll = try #require(views.compactMap { $0 as? NSScrollView }.first)
        let textView = try #require(views.compactMap { $0 as? NSTextView }.first)
        let copy = try #require(views.compactMap { $0 as? NSButton }.first { $0.title == "Text kopieren" })
        let labels = views.compactMap { $0 as? NSTextField }.map(\.stringValue).joined(separator: "\n")
        #expect(panel.display == .manual)
        #expect(!scroll.isHidden)
        #expect(textView.string == "Vollständiger Text")
        #expect(copy.isEnabled && !copy.isHidden)
        #expect(labels.contains("Nicht automatisch eingefügt"))
        #expect(!labels.contains("Möglicherweise"))
    }
}
