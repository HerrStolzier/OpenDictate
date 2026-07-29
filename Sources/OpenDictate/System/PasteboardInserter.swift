import AppKit
import ApplicationServices
import Carbon
import Foundation

@MainActor
struct PasteboardInserter {
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func pasteIntoPreviousApp(_ app: NSRunningApplication?) async -> Bool {
        guard AXIsProcessTrusted(), let app else {
            AppLog.write("Auto-paste unavailable. accessibility=\(AXIsProcessTrusted()), previousApp=\(app?.localizedName ?? "none")")
            return false
        }

        app.activate()
        try? await Task.sleep(for: .milliseconds(250))
        return simulateCommandV()
    }

    private func simulateCommandV() -> Bool {
        let virtualVKey: CGKeyCode = 0x09

        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualVKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualVKey, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
