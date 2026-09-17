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
        var bundleIdentifier: String?
        var secureInput = false
        var missing = false
        var needsUnicode = true
        var nativeSucceeds = true
        var native: [String] = []
        var unicode: [[UniChar]] = []
        var afterChunk: (() -> Void)?

        var snapshot: InsertionTarget? {
            guard !missing else { return nil }
            return InsertionTarget(
                pid: 42, window: AXUIElementCreateApplication(window), element: AXUIElementCreateApplication(field),
                document: document.map(AXUIElementCreateApplication), selection: selection,
                role: role, subrole: subrole, enabled: enabled, acceptsSelectedText: settable,
                bundleIdentifier: bundleIdentifier)
        }

        func useTerminal() {
            bundleIdentifier = "com.apple.Terminal"
            document = nil
            selection = CFRange(location: 3, length: 0)
            settable = false
        }

        lazy var inserter = PasteboardInserter(
            access: .init(
                isTrusted: { self.trusted }, frontmostPID: { self.frontmost }, focusedTarget: { _ in self.snapshot },
                needsUnicodeEvents: { _ in self.needsUnicode },
                insertSelectedText: { _, text in
                    self.native.append(text)
                    return self.nativeSucceeds
                },
                postUnicode: { pid, units in
                    #expect(pid == 42)
                    self.unicode.append(units)
                    self.afterChunk?()
                    return true
                }, isSecureInputEnabled: { self.secureInput }))
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
            #expect(await h.inserter.paste("original transcript", into: target) == .notAttempted)
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
            #expect(await h.inserter.paste("text", into: target) == .notAttempted)
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
            #expect(await h.inserter.paste("text", into: initial) == .notAttempted)
            #expect(h.native.isEmpty && h.unicode.isEmpty)
        }
    }

    @Test func missingStartTargetCannotAdoptLaterFocusedField() async {
        let h = Harness()
        h.missing = true
        let captured = h.inserter.captureTarget(in: 42)
        h.missing = false
        #expect(await h.inserter.paste("text", into: captured) == .notAttempted)
        #expect(h.unicode.isEmpty)
    }

    @Test func nativeInsertionUsesExactCapturedElementOnce() async {
        let h = Harness()
        h.document = nil
        let target = h.inserter.captureTarget(in: 42)
        #expect(await h.inserter.paste("Äpfel 🍏", into: target) == .submitted)
        #expect(h.native == ["Äpfel 🍏"])
        #expect(h.unicode.isEmpty)
    }

    @Test func nativeTextViewMayOmitEnabledButMustExposeWritableSelection() async {
        let h = Harness()
        h.enabled = nil
        h.document = nil
        let target = h.inserter.captureTarget(in: 42)
        #expect(target != nil)
        #expect(await h.inserter.paste("text", into: target) == .submitted)
        #expect(h.native == ["text"])
        h.settable = false
        #expect(h.inserter.captureTarget(in: 42) == nil)
    }

    @Test func webInputIsExactAndOwnSelectionMovementDoesNotAbort() async {
        let h = Harness()
        let target = h.inserter.captureTarget(in: 42)
        let text = String(repeating: "Grüße 🍏! ", count: 8)
        h.afterChunk = { h.selection = CFRange(location: 99, length: 0) }
        #expect(await h.inserter.paste(text, into: target) == .submitted)
        #expect(String(decoding: h.unicode.flatMap { $0 }, as: UTF16.self) == text)
        #expect(h.native.isEmpty)
    }

    @Test func otherWebEnginesKeepAXRouteWithoutDuplicateFallback() async {
        let h = Harness()
        h.needsUnicode = false
        let target = h.inserter.captureTarget(in: 42)
        #expect(await h.inserter.paste("text", into: target) == .submitted)
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
            #expect(await h.inserter.paste("Before\nAfter", into: target) == .submitted)
            #expect(h.unicode.count == (policy == .isolated ? 3 : 1))
            #expect(String(decoding: h.unicode.flatMap { $0 }, as: UTF16.self) == "Before\nAfter")
        }
    }

    @Test func changedFieldDuringChunksStopsRatherThanResuming() async {
        let h = Harness()
        let target = h.inserter.captureTarget(in: 42)
        h.afterChunk = { h.field = 102 }
        #expect(await h.inserter.paste(String(repeating: "x", count: 70), into: target) == .interrupted)
        #expect(h.unicode.count == 1)
    }

    @Test func explicitPanelCaptureDoesNotRequirePanelToStealFocusBack() async {
        let h = Harness()
        h.frontmost = 999  // OpenDictate panel is currently frontmost.
        let target = h.inserter.captureTarget(in: 42)
        #expect(target != nil)
        #expect(await h.inserter.paste("text", into: target) == .notAttempted)
        h.frontmost = 42
        #expect(await h.inserter.paste("text", into: target) == .submitted)
    }

    @Test func nativeErrorDoesNotProveNoInsertionAndNeverRetries() async {
        let h = Harness()
        h.document = nil
        h.nativeSucceeds = false
        let target = h.inserter.captureTarget(in: 42)
        #expect(await h.inserter.paste("text", into: target) == .uncertain)
        #expect(h.native == ["text"])
        #expect(h.unicode.isEmpty)
    }

    @Test func terminalDisplayUsesUnicodeRegardlessOfAXWritability() async {
        for settable in [false, true] {
            let h = Harness()
            h.useTerminal()
            h.settable = settable
            let target = h.inserter.captureTarget(in: 42)
            #expect(target != nil)
            let text = String(repeating: "Grüße 🍏 e\u{301} 👩🏽‍💻 ", count: 3)
            h.afterChunk = { h.selection = CFRange(location: 99, length: 0) }
            #expect(await h.inserter.paste(text, into: target) == .submitted)
            #expect(String(decoding: h.unicode.flatMap { $0 }, as: UTF16.self) == text)
            #expect(h.native.isEmpty)
        }
    }

    @Test func terminalExceptionDoesNotAdmitOtherReadonlyOrProtectedControls() async {
        for change in 0..<8 {
            let h = Harness()
            h.useTerminal()
            switch change {
            case 0: h.bundleIdentifier = nil
            case 1: h.bundleIdentifier = "com.googlecode.iterm2"
            case 2: h.bundleIdentifier = "com.apple.TextEdit"
            case 3: h.role = kAXTextFieldRole
            case 4: h.subrole = kAXSecureTextFieldSubrole
            case 5: h.enabled = false
            case 6: h.document = 301
            default: h.selection = CFRange(location: 3, length: 1)
            }
            let target = h.inserter.captureTarget(in: 42)
            #expect(target == nil)
            #expect(await h.inserter.paste("text", into: target) == .notAttempted)
            #expect(h.native.isEmpty && h.unicode.isEmpty)
        }
    }

    @Test func terminalMayOmitDisplaySelectionRange() async {
        let h = Harness()
        h.useTerminal()
        h.selection = nil
        let target = h.inserter.captureTarget(in: 42)
        #expect(target != nil)
        #expect(await h.inserter.paste("text", into: target) == .submitted)
        #expect(h.unicode == [Array("text".utf16)])
        #expect(h.native.isEmpty)
    }

    @Test func terminalSecureInputAtCaptureCannotAdoptALaterTarget() async {
        let h = Harness()
        h.useTerminal()
        h.secureInput = true
        let target = h.inserter.captureTarget(in: 42)
        #expect(target == nil)
        h.secureInput = false
        #expect(await h.inserter.paste("text", into: target) == .notAttempted)
        #expect(h.native.isEmpty && h.unicode.isEmpty)
    }

    @Test func terminalSecureInputAfterCapturePreventsAllEvents() async {
        let h = Harness()
        h.useTerminal()
        let target = h.inserter.captureTarget(in: 42)
        h.secureInput = true
        #expect(await h.inserter.paste("text", into: target) == .notAttempted)
        #expect(h.native.isEmpty && h.unicode.isEmpty)
    }

    @Test func terminalPreflightRemainsBoundToOriginalAppWindowFieldAndSelection() async {
        for change in 0..<5 {
            let h = Harness()
            h.useTerminal()
            let target = h.inserter.captureTarget(in: 42)
            switch change {
            case 0: h.frontmost = 43
            case 1: h.window = 202
            case 2: h.field = 102
            case 3: h.bundleIdentifier = "other.application"
            default: h.selection = CFRange(location: 4, length: 0)
            }
            #expect(await h.inserter.paste("text", into: target) == .notAttempted)
            #expect(h.native.isEmpty && h.unicode.isEmpty)
        }
    }

    @Test func terminalFocusProtectionOrDisplaySelectionStopsRemainingChunks() async {
        for change in 0..<6 {
            let h = Harness()
            h.useTerminal()
            let target = h.inserter.captureTarget(in: 42)
            h.afterChunk = {
                switch change {
                case 0: h.secureInput = true
                case 1: h.frontmost = 43
                case 2: h.window = 202
                case 3: h.field = 102
                case 4: h.document = 301
                default: h.selection = CFRange(location: 3, length: 1)
                }
            }
            #expect(await h.inserter.paste(String(repeating: "x", count: 65), into: target) == .interrupted)
            #expect(h.unicode.count == 1)
            #expect(h.native.isEmpty)
        }
    }

    @Test func terminalRechecksSecureInputAfterReadingFocusMetadata() async {
        let h = Harness()
        h.useTerminal()
        let target = h.inserter.captureTarget(in: 42)
        h.inserter.access.focusedTarget = { _ in
            if !h.unicode.isEmpty { h.secureInput = true }
            return h.snapshot
        }
        #expect(await h.inserter.paste(String(repeating: "x", count: 65), into: target) == .interrupted)
        #expect(h.unicode.count == 1)
        #expect(h.native.isEmpty)
    }

    @Test func terminalChecksTheWholeTranscriptBeforePostingAnyPrefix() async {
        for unsafe in ["\r", "\n", "\t", "\u{1B}", "\u{7F}", "\u{85}", "\u{2028}", "\u{2029}", "\u{F700}"] {
            let h = Harness()
            h.useTerminal()
            let target = h.inserter.captureTarget(in: 42)
            let text = String(repeating: "x", count: 65) + unsafe + "after"
            #expect(await h.inserter.paste(text, into: target) == .notAttempted)
            #expect(h.native.isEmpty && h.unicode.isEmpty)
        }
    }

    @Test func terminalControlCharacterPolicyDoesNotChangeOrdinaryEditors() async {
        let h = Harness()
        h.document = nil
        let target = h.inserter.captureTarget(in: 42)
        #expect(await h.inserter.paste("Before\nAfter\tText", into: target) == .submitted)
        #expect(h.native == ["Before\nAfter\tText"])
        #expect(h.unicode.isEmpty)
    }
}
