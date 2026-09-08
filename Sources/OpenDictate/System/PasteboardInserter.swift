import AppKit
import ApplicationServices
import Foundation

@MainActor
struct PasteboardInserter {
    func copy(_ text: String) -> Bool {
        let board = NSPasteboard.general
        board.clearContents()
        return board.setString(text, forType: .string)
    }

    func pasteIntoPreviousApp(_ app: NSRunningApplication?, text: String) async -> Bool {
        guard !text.isEmpty, !Task.isCancelled, AXIsProcessTrusted(), let app, !app.isTerminated else {
            AppLog.write(
                "Auto-paste unavailable. accessibility=\(AXIsProcessTrusted()), previousApp=\(app?.localizedName ?? "none")"
            )
            return false
        }

        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
            AppLog.write("Auto-paste skipped: user changed the foreground application")
            return false
        }
        guard app.activate() else {
            AppLog.write("Auto-paste aborted because the target app could not be activated")
            return false
        }

        let deadline = ContinuousClock.now.advanced(by: .milliseconds(750))
        while !Task.isCancelled && ContinuousClock.now < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
                return insert(text, into: app.processIdentifier)
            }
            try? await Task.sleep(for: .milliseconds(25))
        }

        AppLog.write("Auto-paste aborted because the intended target never became frontmost")
        return false
    }

    private func insert(_ text: String, into targetPID: pid_t) -> Bool {
        let application = AXUIElementCreateApplication(targetPID)
        var focusedValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                application,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            ) == .success,
            let focusedValue
        else {
            AppLog.write("Auto-paste unavailable: target has no accessible focused element")
            return false
        }

        let focusedElement = focusedValue as! AXUIElement
        var focusedPID: pid_t = 0
        guard
            AXUIElementGetPid(focusedElement, &focusedPID) == .success,
            focusedPID == targetPID
        else {
            AppLog.write("Auto-paste aborted: focused element belongs to another process")
            return false
        }

        var isSettable = DarwinBoolean(false)
        guard
            AXUIElementIsAttributeSettable(
                focusedElement,
                kAXSelectedTextAttribute as CFString,
                &isSettable
            ) == .success,
            isSettable.boolValue
        else {
            AppLog.write("Auto-paste unavailable: focused element does not accept selected text")
            return false
        }

        let status = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        if status != .success {
            AppLog.write("Auto-paste failed with AX error \(status.rawValue)")
        }
        return status == .success
    }
}
