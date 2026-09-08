import Foundation

/// A global shortcut, described in the raw values Carbon's `RegisterEventHotKey`
/// expects. The numbers are duplicated here on purpose so this module stays free
/// of Carbon; `HotKeyShortcut.carbonConstantsMatch` lets the app assert they still
/// agree with the SDK at launch.
public struct HotKeyShortcut: Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let displayName: String

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    // Carbon modifier masks.
    public static let shiftMask: UInt32 = 512
    public static let controlMask: UInt32 = 4096
    public static let optionMask: UInt32 = 2048
    public static let commandMask: UInt32 = 256

    // Carbon virtual key codes.
    public static let spaceKeyCode: UInt32 = 49
    public static let dKeyCode: UInt32 = 2
    public static let f5KeyCode: UInt32 = 96

    public static let optionShiftSpace = HotKeyShortcut(
        keyCode: spaceKeyCode,
        modifiers: optionMask | shiftMask,
        displayName: "Option+Shift+Space"
    )

    public static let controlOptionD = HotKeyShortcut(
        keyCode: dKeyCode,
        modifiers: controlMask | optionMask,
        displayName: "Control+Option+D"
    )

    public static let f5 = HotKeyShortcut(
        keyCode: f5KeyCode,
        modifiers: 0,
        displayName: "F5"
    )

    public static let presets: [HotKeyShortcut] = [.optionShiftSpace, .controlOptionD, .f5]
    public static let `default` = HotKeyShortcut.optionShiftSpace

    public static func custom(keyCode: UInt32, modifiers: UInt32, displayName: String) -> HotKeyShortcut? {
        let allowed = shiftMask | controlMask | optionMask | commandMask
        guard keyCode <= 126, modifiers & ~allowed == 0,
              modifiers & (controlMask | optionMask | commandMask) != 0,
              !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              displayName.count <= 80 else { return nil }
        return HotKeyShortcut(keyCode: keyCode, modifiers: modifiers, displayName: displayName)
    }

    /// Matches a stored key code and modifier pair back to a preset. Returns nil
    /// for anything unrecognised, so a stale or hand-edited preference falls back
    /// to the default instead of registering a shortcut with no label.
    public static func preset(keyCode: UInt32, modifiers: UInt32) -> HotKeyShortcut? {
        presets.first { $0.keyCode == keyCode && $0.modifiers == modifiers }
    }

    /// Cross-check hook for the app, which does have Carbon and can pass the real
    /// SDK values in.
    public static func carbonConstantsMatch(
        space: UInt32,
        d: UInt32,
        f5: UInt32,
        shift: UInt32,
        control: UInt32,
        option: UInt32
    ) -> Bool {
        space == spaceKeyCode
            && d == dKeyCode
            && f5 == f5KeyCode
            && shift == shiftMask
            && control == controlMask
            && option == optionMask
    }
}
