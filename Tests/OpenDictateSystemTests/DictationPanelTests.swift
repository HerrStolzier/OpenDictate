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

    @Test func interruptedOrUncertainInsertionShowsCompleteTextAndCopyWithoutClaimingNoInsertion() throws {
        for outcome in [DictationOutcome.deliveryInterrupted, .deliveryUncertain] {
            let panel = DictationPanel()
            defer { panel.close() }
            let text = "Vollständiger Text.\nGrüße 🍏 und e\u{301}."
            var copied = 0
            panel.onCopy = { copied += 1 }
            panel.update(state: .delivering)
            panel.update(outcome: outcome, transcript: text)
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
