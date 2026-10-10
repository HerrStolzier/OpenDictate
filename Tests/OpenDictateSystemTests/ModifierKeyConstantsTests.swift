import AppKit
import Carbon
import IOKit.hidsystem
import Testing

@testable import OpenDictateCore

/// OpenDictateCore duplicates AppKit and IOKit values to stay free of them.
/// If the SDK ever changed one, the single-key trigger would watch the wrong key.
@Suite("Single-key constants match the SDK")
struct ModifierKeyConstantsTests {
    @Test func keyCodesAndFlagsMatch() {
        #expect(ModifierKey.fn.keyCode == UInt16(kVK_Function))
        #expect(ModifierKey.rightOption.keyCode == UInt16(kVK_RightOption))
        #expect(ModifierKey.functionFlag == NSEvent.ModifierFlags.function.rawValue)
        #expect(ModifierKey.capsLockFlag == NSEvent.ModifierFlags.capsLock.rawValue)
        #expect(ModifierKey.shiftFlag == NSEvent.ModifierFlags.shift.rawValue)
        #expect(ModifierKey.controlFlag == NSEvent.ModifierFlags.control.rawValue)
        #expect(ModifierKey.optionFlag == NSEvent.ModifierFlags.option.rawValue)
        #expect(ModifierKey.commandFlag == NSEvent.ModifierFlags.command.rawValue)
        #expect(ModifierKey.leftOptionDeviceFlag == UInt(NX_DEVICELALTKEYMASK))
        #expect(ModifierKey.rightOptionDeviceFlag == UInt(NX_DEVICERALTKEYMASK))
    }
}
