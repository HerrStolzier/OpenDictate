import AppKit
import Testing

@testable import OpenDictate

@Suite("Shortcut dialog keyboard navigation")
@MainActor
struct ShortcutCaptureTests {
    init() { _ = NSApplication.shared }

    private func event(_ code: UInt16, flags: NSEvent.ModifierFlags = [], text: String = "") -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text,
            isARepeat: false, keyCode: code)!
    }

    @Test func dialogCommandsPreserveCapturedShortcut() {
        let view = ShortcutCaptureView(frame: .zero)
        view.keyDown(with: event(49, flags: .option, text: " "))
        let captured = view.shortcut
        var confirmed = 0
        var cancelled = 0
        view.onConfirm = { confirmed += 1 }
        view.onCancel = { cancelled += 1 }
        for code: UInt16 in [48, 53, 36, 76] {
            view.keyDown(with: event(code))
        }
        view.keyDown(with: event(48, flags: .shift))
        #expect(view.shortcut == captured)
        #expect(confirmed == 2)
        #expect(cancelled == 1)
    }

    @Test func navigationKeysWithShortcutModifiersRemainRecordable() {
        let view = ShortcutCaptureView(frame: .zero)
        var dialogAction = false
        view.onConfirm = { dialogAction = true }
        view.onCancel = { dialogAction = true }
        for code: UInt16 in [48, 53, 36] {
            view.keyDown(with: event(code, flags: .option))
            #expect(view.shortcut?.keyCode == UInt32(code))
        }
        #expect(!dialogAction)
    }

    @Test func unfocusedCaptureDoesNotConsumeWindowKeyEquivalents() {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: .titled, backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        let first = ShortcutCaptureView(frame: NSRect(x: 0, y: 0, width: 180, height: 30))
        let second = ShortcutCaptureView(frame: NSRect(x: 200, y: 0, width: 180, height: 30))
        window.contentView?.addSubview(first)
        window.contentView?.addSubview(second)
        first.nextKeyView = second
        second.nextKeyView = first
        #expect(window.makeFirstResponder(first))
        #expect(first.performKeyEquivalent(with: event(49, flags: .option, text: " ")))
        #expect(first.shortcut != nil)
        first.keyDown(with: event(48))
        #expect(window.firstResponder === second)
        #expect(!first.performKeyEquivalent(with: event(0, flags: .command, text: "a")))
        second.keyDown(with: event(48, flags: .shift))
        #expect(window.firstResponder === first)
        window.close()
    }
}
