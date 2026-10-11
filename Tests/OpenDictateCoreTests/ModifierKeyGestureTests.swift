import Testing

@testable import OpenDictateCore

@Suite("Single modifier key gestures")
struct ModifierKeyGestureTests {
    private func press(_ gesture: inout ModifierKeyGesture, at time: Double = 0) -> UInt64 {
        gesture.keyDown(at: time, otherModifiersHeld: false)!
    }

    @Test("A short press of the right Option key on its own is a tap")
    func rightOptionTap() {
        var gesture = ModifierKeyGesture(key: .rightOption)
        let id = press(&gesture, at: 10)
        #expect(gesture.keyUp(at: 10.1) == .tap)
        #expect(gesture.holdDeadlineReached(pressID: id) == nil)
    }

    @Test("Holding the right Option key past the threshold records until release")
    func rightOptionHold() {
        var gesture = ModifierKeyGesture(key: .rightOption)
        let id = press(&gesture, at: 10)
        #expect(gesture.holdDeadlineReached(pressID: id) == .holdBegan)
        #expect(gesture.keyUp(at: 12) == .holdEnded)
    }

    @Test("Option+L for @ stays typing: another key during the press cancels the gesture")
    func otherKeyKeepsCombinationsWorking() {
        var gesture = ModifierKeyGesture(key: .rightOption)
        let id = press(&gesture)
        #expect(gesture.otherInput() == nil)
        #expect(gesture.holdDeadlineReached(pressID: id) == nil)
        #expect(gesture.keyUp(at: 0.1) == nil)
        // The next clean press works again.
        _ = press(&gesture, at: 1)
        #expect(gesture.keyUp(at: 1.1) == .tap)
    }

    @Test("Another key after the hold began interrupts it instead of ending it normally")
    func otherKeyInterruptsHold() {
        var gesture = ModifierKeyGesture(key: .fn)
        let id = press(&gesture)
        #expect(gesture.holdDeadlineReached(pressID: id) == .holdBegan)
        #expect(gesture.otherInput() == .holdInterrupted)
        #expect(gesture.keyUp(at: 2) == nil)
    }

    @Test("Fn only reacts to holding; a short tap is left to macOS")
    func fnIgnoresTaps() {
        var gesture = ModifierKeyGesture(key: .fn)
        _ = press(&gesture)
        #expect(gesture.keyUp(at: 0.1) == nil)
        let id = press(&gesture, at: 1)
        #expect(gesture.holdDeadlineReached(pressID: id) == .holdBegan)
        #expect(gesture.keyUp(at: 3) == .holdEnded)
    }

    @Test("A press that starts while another modifier is held never counts")
    func pressWithHeldModifier() {
        var gesture = ModifierKeyGesture(key: .rightOption)
        #expect(gesture.keyDown(at: 0, otherModifiersHeld: true) == nil)
        #expect(gesture.keyUp(at: 0.1) == nil)
    }

    @Test("A release at or beyond the threshold without a reported hold is not a tap")
    func slowReleaseIsNoTap() {
        var gesture = ModifierKeyGesture(key: .rightOption)
        _ = press(&gesture)
        #expect(gesture.keyUp(at: ModifierKeyGesture.holdThreshold) == nil)
    }

    @Test("A deadline from an earlier press cannot start a hold for a later one")
    func staleDeadlineIsIgnored() {
        var gesture = ModifierKeyGesture(key: .rightOption)
        let first = press(&gesture)
        _ = gesture.keyUp(at: 0.1)
        _ = press(&gesture, at: 1)
        #expect(gesture.holdDeadlineReached(pressID: first) == nil)
    }

    @Test("Key state is read from the device bits; Caps Lock does not block a press")
    func modifierFlags() {
        let rightOptionDown: UInt = (1 << 19) | 0x40
        #expect(ModifierKey.rightOption.isPressed(rawModifierFlags: rightOptionDown))
        #expect(!ModifierKey.rightOption.isPressed(rawModifierFlags: (1 << 19) | 0x20))
        #expect(!ModifierKey.rightOption.otherModifiersHeld(rawModifierFlags: rightOptionDown | (1 << 16)))
        #expect(ModifierKey.rightOption.otherModifiersHeld(rawModifierFlags: rightOptionDown | 0x20))
        #expect(ModifierKey.rightOption.otherModifiersHeld(rawModifierFlags: rightOptionDown | (1 << 17)))
        #expect(ModifierKey.fn.isPressed(rawModifierFlags: 1 << 23))
        #expect(!ModifierKey.fn.otherModifiersHeld(rawModifierFlags: (1 << 23) | (1 << 16)))
        #expect(ModifierKey.fn.otherModifiersHeld(rawModifierFlags: (1 << 23) | (1 << 20)))
    }
}

@Suite("Single key recommended for the connected keyboards")
struct ModifierKeyRecommendationTests {
    private let builtIn = KeyboardDevice(vendorID: 0x05AC, productID: 0x0343, isBuiltIn: true)
    private let compactMagic = KeyboardDevice(vendorID: 0x004C, productID: 0x029C, isBuiltIn: false)
    private let numpadMagic = KeyboardDevice(vendorID: 0x004C, productID: 0x026C, isBuiltIn: false)
    private let otherBrand = KeyboardDevice(vendorID: 0x046D, productID: 0xB35B, isBuiltIn: false)

    @Test("A MacBook keyboard or a compact Magic Keyboard gets Fn")
    func compactLayoutsGetFn() {
        #expect(ModifierKey.recommended(for: [builtIn]) == .fn)
        #expect(ModifierKey.recommended(for: [builtIn, compactMagic]) == .fn)
    }

    @Test("A Magic Keyboard with numeric keypad gets the right Option key, even next to a MacBook")
    func numpadGetsRightOption() {
        #expect(ModifierKey.recommended(for: [numpadMagic]) == .rightOption)
        #expect(ModifierKey.recommended(for: [builtIn, numpadMagic]) == .rightOption)
        #expect(
            ModifierKey.recommended(for: [KeyboardDevice(vendorID: 0x05AC, productID: 0x0322, isBuiltIn: false)])
                == .rightOption)
        // Older wired aluminium keyboard with keypad.
        #expect(
            ModifierKey.recommended(for: [KeyboardDevice(vendorID: 0x05AC, productID: 0x0250, isBuiltIn: false)])
                == .rightOption)
    }

    @Test("Another brand gets the right Option key, because macOS may not see its Fn")
    func otherBrandGetsRightOption() {
        #expect(ModifierKey.recommended(for: [otherBrand]) == .rightOption)
        // Without readable IDs the device is treated like another brand.
        #expect(
            ModifierKey.recommended(for: [KeyboardDevice(vendorID: 0, productID: 0, isBuiltIn: false)]) == .rightOption)
    }

    @Test("Without a detected keyboard Fn stays the recommendation")
    func nothingDetected() {
        #expect(ModifierKey.recommended(for: []) == .fn)
    }

    @Test("The recommended key comes first, the other single key second, Control+Option+D third")
    func setupOrder() {
        #expect(
            RecordingTrigger.setupChoices(recommending: .rightOption) == [
                .modifierKey(.rightOption), .modifierKey(.fn), .combination(.controlOptionD)
            ])
        #expect(RecordingTrigger.setupChoices(recommending: .fn).first == .modifierKey(.fn))
    }
}
