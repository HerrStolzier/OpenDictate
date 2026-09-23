import AppKit
import Testing

@testable import OpenDictate

@Suite("Application paste delivery without system input")
@MainActor
struct PasteboardInserterTests {
    @MainActor
    final class Harness {
        let app = NSRunningApplication.current
        let board = NSPasteboard.withUniqueName()
        var trusted = true
        var frontmost: pid_t?
        var activated = 0
        var posted = 0
        var afterActivation: (() -> Void)?

        init() { frontmost = app.processIdentifier }

        lazy var inserter = PasteboardInserter(
            access: .init(
                isTrusted: { self.trusted },
                isRunning: { _ in true },
                frontmostPID: { self.frontmost },
                activate: { _ in self.activated += 1 },
                settle: { self.afterActivation?() },
                postCommandV: {
                    self.posted += 1
                    return true
                }))

    }

    @Test func ordinaryPasteDoesNotRequireAXFieldMetadata() async {
        let h = Harness()
        defer { h.board.releaseGlobally() }
        #expect(h.inserter.copy("Äpfel 🍏", to: h.board))
        #expect(await h.inserter.paste("Äpfel 🍏", into: h.app, board: h.board) == .submitted)
        #expect(h.activated == 1)
        #expect(h.posted == 1)
    }

    @Test func changedForegroundAppDoesNotReceivePasteCommand() async {
        let h = Harness()
        defer { h.board.releaseGlobally() }
        #expect(h.inserter.copy("text", to: h.board))
        h.afterActivation = { h.frontmost = h.app.processIdentifier + 1 }
        #expect(await h.inserter.paste("text", into: h.app, board: h.board) == .notAttempted)
        #expect(h.activated == 1)
        #expect(h.posted == 0)
    }

    @Test func changedClipboardDoesNotPasteUnrelatedContents() async {
        let h = Harness()
        defer { h.board.releaseGlobally() }
        #expect(h.inserter.copy("text", to: h.board))
        h.afterActivation = { _ = h.inserter.copy("changed", to: h.board) }
        #expect(await h.inserter.paste("text", into: h.app, board: h.board) == .notAttempted)
        #expect(h.posted == 0)
    }

    @Test func unavailablePermissionOrTargetDoesNotActivate() async {
        let h = Harness()
        defer { h.board.releaseGlobally() }
        #expect(h.inserter.copy("text", to: h.board))
        h.trusted = false
        #expect(await h.inserter.paste("text", into: h.app, board: h.board) == .notAttempted)
        h.trusted = true
        #expect(await h.inserter.paste("text", into: nil, board: h.board) == .notAttempted)
        #expect(h.activated == 0)
        #expect(h.posted == 0)
    }
}
