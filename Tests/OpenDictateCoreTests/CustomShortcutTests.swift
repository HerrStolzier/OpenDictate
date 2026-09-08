import Testing
@testable import OpenDictateCore

@Suite("Custom shortcut validation")
struct CustomShortcutTests {
    @Test func rejectsUnmodifiedTypingAndUnknownModifiers() {
        #expect(HotKeyShortcut.custom(keyCode: 0, modifiers: 0, displayName: "A") == nil)
        #expect(HotKeyShortcut.custom(keyCode: 0, modifiers: .max, displayName: "A") == nil)
        #expect(HotKeyShortcut.custom(keyCode: 200, modifiers: HotKeyShortcut.optionMask, displayName: "A") == nil)
    }
    @Test func acceptsModifiedKeys() {
        #expect(HotKeyShortcut.custom(keyCode: 0, modifiers: HotKeyShortcut.optionMask, displayName: "⌥A") != nil)
    }
}
