import AppKit
import ApplicationServices
import OpenDictateCore

@MainActor
struct PasteboardInserter {
    @MainActor
    struct Access {
        var isTrusted: @MainActor () -> Bool
        var isRunning: @MainActor (NSRunningApplication) -> Bool
        var frontmostPID: @MainActor () -> pid_t?
        var activate: @MainActor (NSRunningApplication) -> Void
        var settle: @MainActor () async -> Void
        var postCommandV: @MainActor () -> Bool

        static var live: Access {
            Access(
                isTrusted: { AXIsProcessTrusted() },
                isRunning: { !$0.isTerminated },
                frontmostPID: { NSWorkspace.shared.frontmostApplication?.processIdentifier },
                activate: { $0.activate() },
                settle: { try? await Task.sleep(for: .milliseconds(250)) },
                postCommandV: {
                    let virtualVKey: CGKeyCode = 0x09
                    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: virtualVKey, keyDown: true),
                        let up = CGEvent(keyboardEventSource: nil, virtualKey: virtualVKey, keyDown: false)
                    else { return false }
                    down.flags = .maskCommand
                    up.flags = .maskCommand
                    down.post(tap: .cghidEventTap)
                    up.post(tap: .cghidEventTap)
                    return true
                })
        }
    }

    var access: Access = .live

    func copy(_ text: String, to board: NSPasteboard = .general) -> Bool {
        board.clearContents()
        return board.setString(text, forType: .string)
    }

    /// The original delivery path: activate the app present when dictation began,
    /// then let its focused control handle the normal Paste command.
    func paste(_ text: String, into app: NSRunningApplication?, board: NSPasteboard = .general) async
        -> InsertionSubmission
    {
        guard !text.isEmpty, !Task.isCancelled, access.isTrusted(), let app, access.isRunning(app),
            board.string(forType: .string) == text
        else { return .notAttempted }
        access.activate(app)
        await access.settle()
        guard !Task.isCancelled, access.isTrusted(), access.isRunning(app),
            access.frontmostPID() == app.processIdentifier, board.string(forType: .string) == text
        else { return .notAttempted }
        return access.postCommandV() ? .submitted : .notAttempted
    }
}
