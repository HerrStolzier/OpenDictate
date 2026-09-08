import Carbon
import Testing
import OpenDictateCore
@testable import OpenDictate

@Suite("Hotkey transaction without hardware registration")
struct HotKeyTransactionTests {
    @Test func collisionKeepsPreviousRegistration() throws {
        var removed = 0
        let manager = HotKeyManager(register: { shortcut, _ in
            if shortcut == .f5 { throw OpenDictateError.hotKeyRegistrationFailed(-9878) }
            return EventHotKeyRef(bitPattern: 1)!
        }, unregister: { _ in removed += 1 })
        try manager.register(.default, action: {})
        #expect(throws: OpenDictateError.self) { try manager.register(.f5, action: {}) }
        #expect(manager.registeredShortcut == .default)
        #expect(removed == 0)
        try manager.register(.controlOptionD, action: {})
        #expect(manager.registeredShortcut == .controlOptionD)
        #expect(removed == 1)
    }
}
