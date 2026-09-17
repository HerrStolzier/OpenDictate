import AppKit
import Testing

@testable import OpenDictate

@Suite("Captured insertion target without system input")
@MainActor
struct InsertionTargetTests {
    @MainActor
    final class Harness {
        var frontmost: pid_t? = 42
        var trusted = true
        var field: pid_t = 101
        var window: pid_t = 201
        var document: pid_t? = 301
        var selection: CFRange? = CFRange(location: 3, length: 2)
        var role = kAXTextAreaRole
        var subrole: String?
        var enabled: Bool? = true
        var settable = true
        var missing = false
        var needsUnicode = true
        var native: [String] = []
        var unicode: [[UniChar]] = []
        var afterChunk: (() -> Void)?

        var snapshot: InsertionTarget? {
            guard !missing else { return nil }
            return InsertionTarget(
                pid: 42, window: AXUIElementCreateApplication(window), element: AXUIElementCreateApplication(field),
                document: document.map(AXUIElementCreateApplication), selection: selection,
                role: role, subrole: subrole, enabled: enabled, acceptsSelectedText: settable)
        }

        lazy var inserter = PasteboardInserter(
            access: .init(
                isTrusted: { self.trusted }, frontmostPID: { self.frontmost }, focusedTarget: { _ in self.snapshot },
                needsUnicodeEvents: { _ in self.needsUnicode },
                insertSelectedText: { _, text in
                    self.native.append(text)
                    return true
                },
                postUnicode: { pid, units in
                    #expect(pid == 42)
                    self.unicode.append(units)
                    self.afterChunk?()
                    return true
                }))
    }

    @Test func sameApplicationFieldWindowAndTabSwitchesNeverRedirect() async {
        for change in 0..<4 {
            let h = Harness()
            let target = h.inserter.captureTarget(in: 42)
            #expect(target != nil)
            switch change {
            case 0: h.field = 102
            case 1: h.window = 202
            case 2: h.document = 302
            default: h.frontmost = 43
            }
            #expect(await h.inserter.paste("original transcript", into: target) == false)
            #expect(h.native.isEmpty && h.unicode.isEmpty)
        }
    }

    @Test func changedSelectionOrDestroyedTargetNeverReceivesText() async {
        for change in 0..<3 {
            let h = Harness()
            let target = h.inserter.captureTarget(in: 42)
            if change == 0 { h.selection = CFRange(location: 8, length: 0) }
            if change == 1 { h.selection = nil }
            if change == 2 { h.missing = true }
            #expect(await h.inserter.paste("text", into: target) == false)
            #expect(h.unicode.isEmpty)
        }
    }

    @Test func protectedDisabledUnsupportedAndUntrustedTargetsAreRejected() async {
        for change in 0..<5 {
            let h = Harness()
            let initial = h.inserter.captureTarget(in: 42)
            switch change {
            case 0: h.subrole = kAXSecureTextFieldSubrole
            case 1: h.enabled = false
            case 2: h.settable = false
            case 3: h.role = kAXButtonRole
            default: h.trusted = false
            }
            #expect(h.inserter.captureTarget(in: 42) == nil)
            #expect(await h.inserter.paste("text", into: initial) == false)
            #expect(h.native.isEmpty && h.unicode.isEmpty)
        }
    }

    @Test func missingStartTargetCannotAdoptLaterFocusedField() async {
        let h = Harness()
        h.missing = true
        let captured = h.inserter.captureTarget(in: 42)
        h.missing = false
        #expect(await h.inserter.paste("text", into: captured) == false)
        #expect(h.unicode.isEmpty)
    }

    @Test func nativeInsertionUsesExactCapturedElementOnce() async {
        let h = Harness()
        h.document = nil
        let target = h.inserter.captureTarget(in: 42)
        #expect(await h.inserter.paste("Äpfel 🍏", into: target))
        #expect(h.native == ["Äpfel 🍏"])
        #expect(h.unicode.isEmpty)
    }

    @Test func nativeTextViewMayOmitEnabledButMustExposeWritableSelection() async {
        let h = Harness()
        h.enabled = nil
        h.document = nil
        let target = h.inserter.captureTarget(in: 42)
        #expect(target != nil)
        #expect(await h.inserter.paste("text", into: target))
        #expect(h.native == ["text"])
        h.settable = false
        #expect(h.inserter.captureTarget(in: 42) == nil)
    }

    @Test func webInputIsExactAndOwnSelectionMovementDoesNotAbort() async {
        let h = Harness()
        let target = h.inserter.captureTarget(in: 42)
        let text = String(repeating: "Grüße 🍏! ", count: 8)
        h.afterChunk = { h.selection = CFRange(location: 99, length: 0) }
        #expect(await h.inserter.paste(text, into: target))
        #expect(String(decoding: h.unicode.flatMap { $0 }, as: UTF16.self) == text)
        #expect(h.native.isEmpty)
    }

    @Test func otherWebEnginesKeepAXRouteWithoutDuplicateFallback() async {
        let h = Harness()
        h.needsUnicode = false
        let target = h.inserter.captureTarget(in: 42)
        #expect(await h.inserter.paste("text", into: target))
        #expect(h.native == ["text"])
        #expect(h.unicode.isEmpty)
    }

    @Test func browserLineBreakPoliciesPreserveExactText() async {
        for policy in [
            UnicodeTextDelivery.LineBreakPolicy.grouped, .isolated, .trailing
        ] {
            let h = Harness()
            h.inserter.access.unicodeLineBreakPolicy = { _ in policy }
            let target = h.inserter.captureTarget(in: 42)
            #expect(await h.inserter.paste("Before\nAfter", into: target))
            #expect(h.unicode.count == (policy == .isolated ? 3 : 1))
            #expect(String(decoding: h.unicode.flatMap { $0 }, as: UTF16.self) == "Before\nAfter")
        }
    }

    @Test func changedFieldDuringChunksStopsRatherThanResuming() async {
        let h = Harness()
        let target = h.inserter.captureTarget(in: 42)
        h.afterChunk = { h.field = 102 }
        #expect(await h.inserter.paste(String(repeating: "x", count: 70), into: target) == false)
        #expect(h.unicode.count == 1)
    }

    @Test func explicitPanelCaptureDoesNotRequirePanelToStealFocusBack() async {
        let h = Harness()
        h.frontmost = 999  // OpenDictate panel is currently frontmost.
        let target = h.inserter.captureTarget(in: 42)
        #expect(target != nil)
        #expect(await h.inserter.paste("text", into: target) == false)
        h.frontmost = 42
        #expect(await h.inserter.paste("text", into: target))
    }
}
