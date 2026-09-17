import AppKit
import ApplicationServices
import Carbon
import Foundation
import OpenDictateCore

@MainActor
struct PasteboardInserter {
    @MainActor
    struct Access {
        var isTrusted: @MainActor () -> Bool
        var frontmostPID: @MainActor () -> pid_t?
        var focusedTarget: @MainActor (pid_t) -> InsertionTarget?
        var needsUnicodeEvents: @MainActor (pid_t) -> Bool
        var insertSelectedText: @MainActor (AXUIElement, String) -> Bool
        var postUnicode: @MainActor (pid_t, [UniChar]) -> Bool
        var unicodeLineBreakPolicy: @MainActor (pid_t) -> UnicodeTextDelivery.LineBreakPolicy = { _ in .grouped }
        var isSecureInputEnabled: @MainActor () -> Bool = { IsSecureEventInputEnabled() }

        static var live: Access {
            Access(
                isTrusted: { AXIsProcessTrusted() },
                frontmostPID: { NSWorkspace.shared.frontmostApplication?.processIdentifier },
                focusedTarget: { InsertionTarget.read(pid: $0) },
                needsUnicodeEvents: {
                    guard let id = NSRunningApplication(processIdentifier: $0)?.bundleIdentifier else { return false }
                    return ["com.brave.Browser", "com.apple.Safari", "md.obsidian"].contains(id)
                },
                insertSelectedText: {
                    AXUIElementSetAttributeValue($0, kAXSelectedTextAttribute as CFString, $1 as CFString) == .success
                },
                postUnicode: { pid, units in
                    guard let (down, up) = UnicodeTextDelivery.events(units) else { return false }
                    down.postToPid(pid)
                    up.postToPid(pid)
                    return true
                },
                unicodeLineBreakPolicy: {
                    UnicodeTextDelivery.policy(
                        for: NSRunningApplication(processIdentifier: $0)?.bundleIdentifier)
                })
        }
    }

    var access: Access = .live

    func copy(_ text: String, to board: NSPasteboard = .general) -> Bool {
        board.clearContents()
        return board.setString(text, forType: .string)
    }

    /// Capture at the explicit start action, before permission or provider awaits.
    /// Panel actions may name the last external app while the panel is frontmost.
    func captureTarget(in pid: pid_t?) -> InsertionTarget? {
        guard access.isTrusted(), let pid, let target = access.focusedTarget(pid), target.acceptsInsertion else {
            return nil
        }
        guard !target.requiresTerminalEvents || !access.isSecureInputEnabled() else {
            AppLog.write("Auto-paste capture unavailable: terminal secure input is enabled")
            return nil
        }
        return target
    }

    func paste(_ text: String, into target: InsertionTarget?) async -> InsertionSubmission {
        guard !text.isEmpty, !Task.isCancelled, access.isTrusted(), let target,
            remainsFocused(target, checkSelection: true)
        else {
            AppLog.write("Auto-paste unavailable: original target is missing, protected or changed")
            return .notAttempted
        }
        if target.requiresTerminalEvents {
            guard !access.isSecureInputEnabled() else {
                AppLog.write("Auto-paste unavailable: terminal secure input is enabled")
                return .notAttempted
            }
            guard TerminalInputPolicy.permits(text) else {
                AppLog.write("Auto-paste unavailable: terminal text contains a control or function-key scalar")
                return .notAttempted
            }
            // Terminal's AX text area describes its display, including scrollback.
            // Even a settable AXSelectedText is not the shell's editable buffer.
            return await UnicodeTextDelivery.send(text) {
                access.isTrusted() && remainsFocused(target, checkSelection: false) && !access.isSecureInputEnabled()
            } post: {
                access.postUnicode(target.pid, $0)
            }
        }
        // These web editors can accept AXSelectedText without applying it. Never retry an
        // accepted AX command via Unicode: a delayed edit could duplicate text.
        if target.document != nil && access.needsUnicodeEvents(target.pid) {
            return await UnicodeTextDelivery.send(text, lineBreakPolicy: access.unicodeLineBreakPolicy(target.pid)) {
                access.isTrusted() && remainsFocused(target, checkSelection: false)
            } post: {
                access.postUnicode(target.pid, $0)
            }
        }
        // An AX error (including a timeout) does not prove the destination was unchanged.
        return access.insertSelectedText(target.element, text) ? .submitted : .uncertain
    }

    private func remainsFocused(_ target: InsertionTarget, checkSelection: Bool) -> Bool {
        guard access.frontmostPID() == target.pid, let current = access.focusedTarget(target.pid) else { return false }
        return target.matches(current, checkSelection: checkSelection)
    }
}
