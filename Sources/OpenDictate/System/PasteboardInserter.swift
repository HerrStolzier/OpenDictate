import AppKit
import ApplicationServices
import Carbon
import Foundation

@MainActor
struct PasteboardInserter {
    func copy(_ text: String) -> Bool {
        let board = NSPasteboard.general
        board.clearContents()
        return board.setString(text, forType: .string)
    }

    func pasteIntoPreviousApp(_ app: NSRunningApplication?) async -> Bool {
        guard AXIsProcessTrusted(), let app, !app.isTerminated else {
            AppLog.write("Auto-paste unavailable. accessibility=\(AXIsProcessTrusted()), previousApp=\(app?.localizedName ?? "none")")
            return false
        }

        guard app.activate() else {
            AppLog.write("Auto-paste aborted because the target app could not be activated")
            return false
        }

        let deadline = ContinuousClock.now.advanced(by: .milliseconds(750))
        while ContinuousClock.now < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
                return sendCommandV(targetPID: app.processIdentifier)
            }
            try? await Task.sleep(for: .milliseconds(25))
        }

        AppLog.write("Auto-paste aborted because the intended target never became frontmost")
        return false
    }

    private func sendCommandV(targetPID: pid_t) -> Bool {
        let virtualVKey: CGKeyCode = 0x09
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualVKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualVKey, keyDown: false)
        else { return false }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(targetPID)
        keyUp.postToPid(targetPID)
        return true
    }
}
