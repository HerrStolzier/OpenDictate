import AppKit
import Carbon
import OpenDictateCore
import Testing

@testable import OpenDictate

@Suite("Native hotkey registration with explicit opt-in")
@MainActor
struct NativeHotKeyRegistrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OPENDICTATE_NATIVE_HOTKEY_CHECK"] == "1"))
    func collisionRetainsOriginalSystemRegistrationAndReleasesBoth() throws {
        _ = NSApplication.shared
        let modifiers = HotKeyShortcut.commandMask | HotKeyShortcut.controlMask | HotKeyShortcut.optionMask
        let original = try #require(
            HotKeyShortcut.custom(keyCode: UInt32(kVK_F18), modifiers: modifiers, displayName: "Test F18"))
        let blocked = try #require(
            HotKeyShortcut.custom(keyCode: UInt32(kVK_F19), modifiers: modifiers, displayName: "Test F19"))
        var blocker: EventHotKeyRef?
        let blockedStatus = RegisterEventHotKey(
            blocked.keyCode, blocked.modifiers, EventHotKeyID(signature: fourCharCode("ODTS"), id: 1),
            GetApplicationEventTarget(), 0, &blocker)
        #expect(blockedStatus == noErr)
        guard let blocker else { return }
        var blockerIsRegistered = true
        defer { if blockerIsRegistered { UnregisterEventHotKey(blocker) } }

        var manager: HotKeyManager? = HotKeyManager()
        try manager?.register(original, action: {})
        #expect(throws: OpenDictateError.self) { try manager?.register(blocked, action: {}) }
        #expect(manager?.registeredShortcut == original)

        var duplicate: EventHotKeyRef?
        let retainedStatus = RegisterEventHotKey(
            original.keyCode, original.modifiers, EventHotKeyID(signature: fourCharCode("ODTS"), id: 2),
            GetApplicationEventTarget(), 0, &duplicate)
        if let duplicate { UnregisterEventHotKey(duplicate) }
        #expect(retainedStatus == OSStatus(eventHotKeyExistsErr))

        manager = nil
        var released: EventHotKeyRef?
        let releasedStatus = RegisterEventHotKey(
            original.keyCode, original.modifiers, EventHotKeyID(signature: fourCharCode("ODTS"), id: 3),
            GetApplicationEventTarget(), 0, &released)
        if let released { UnregisterEventHotKey(released) }
        #expect(releasedStatus == noErr)

        #expect(UnregisterEventHotKey(blocker) == noErr)
        blockerIsRegistered = false
        var releasedBlocker: EventHotKeyRef?
        let blockerReleasedStatus = RegisterEventHotKey(
            blocked.keyCode, blocked.modifiers, EventHotKeyID(signature: fourCharCode("ODTS"), id: 4),
            GetApplicationEventTarget(), 0, &releasedBlocker)
        if let releasedBlocker { #expect(UnregisterEventHotKey(releasedBlocker) == noErr) }
        #expect(blockerReleasedStatus == noErr)
    }
}
