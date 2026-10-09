import Foundation

/// A single modifier key used on its own to control dictation. Unlike a Carbon
/// combination it is watched through key events, so the app needs the
/// Accessibility permission for it.
public enum ModifierKey: String, CaseIterable, Sendable {
    /// Fn/Globe: press and hold to record, release to stop.
    case fn
    /// Right Option: tap to start or stop, hold to record until release.
    case rightOption

    public var displayName: String {
        switch self {
        case .fn: "Fn/Globus halten"
        case .rightOption: "Rechte Wahltaste"
        }
    }

    /// Whether a short press toggles recording. A tap on Fn is left to macOS.
    public var supportsTap: Bool { self == .rightOption }

    /// Virtual key code reported by `flagsChanged` events (kVK_Function,
    /// kVK_RightOption).
    public var keyCode: UInt16 {
        switch self {
        case .fn: 63
        case .rightOption: 61
        }
    }

    // Raw NSEvent.ModifierFlags bits, duplicated so this module stays free of AppKit.
    static let capsLockFlag: UInt = 1 << 16
    static let shiftFlag: UInt = 1 << 17
    static let controlFlag: UInt = 1 << 18
    static let optionFlag: UInt = 1 << 19
    static let commandFlag: UInt = 1 << 20
    static let functionFlag: UInt = 1 << 23
    // Device-dependent bits from IOKit's NX_DEVICELALTKEYMASK / NX_DEVICERALTKEYMASK.
    static let leftOptionDeviceFlag: UInt = 0x20
    static let rightOptionDeviceFlag: UInt = 0x40

    /// Whether this key is down according to the raw modifier flags of an event.
    public func isPressed(rawModifierFlags flags: UInt) -> Bool {
        switch self {
        case .fn: flags & Self.functionFlag != 0
        case .rightOption: flags & Self.rightOptionDeviceFlag != 0
        }
    }

    /// Whether any modifier other than this key is held. Caps Lock is a latched
    /// state, not a held key, and never counts.
    public func otherModifiersHeld(rawModifierFlags flags: UInt) -> Bool {
        let others: UInt
        switch self {
        case .fn:
            others = Self.shiftFlag | Self.controlFlag | Self.optionFlag | Self.commandFlag
        case .rightOption:
            if flags & Self.leftOptionDeviceFlag != 0 { return true }
            others = Self.shiftFlag | Self.controlFlag | Self.commandFlag | Self.functionFlag
        }
        return flags & others != 0
    }
}

/// What starts and stops a dictation: a Carbon key combination or a single
/// modifier key.
public enum RecordingTrigger: Equatable, Sendable {
    case combination(HotKeyShortcut)
    case modifierKey(ModifierKey)

    public static let `default` = RecordingTrigger.combination(.default)

    /// Offered in the shortcut menu, single keys first.
    public static let menuChoices: [RecordingTrigger] =
        ModifierKey.allCases.map { .modifierKey($0) } + HotKeyShortcut.presets.map { .combination($0) }

    /// The first-launch choices in their recommended order; the first is preselected.
    public static let setupChoices: [RecordingTrigger] = [
        .modifierKey(.fn), .modifierKey(.rightOption), .combination(.controlOptionD)
    ]

    public var displayName: String {
        switch self {
        case .combination(let shortcut): shortcut.displayName
        case .modifierKey(let key): key.displayName
        }
    }

    /// Single keys are read from key events, which macOS only delivers to
    /// apps trusted under Accessibility.
    public var needsAccessibility: Bool {
        if case .modifierKey = self { return true }
        return false
    }
}

/// Turns the presses of one modifier key into dictation gestures.
///
/// A press counts only while no other key, modifier or mouse button is used.
/// That keeps combinations such as Option+L for "@" working. A press shorter
/// than `holdThreshold` is a tap; a press that lasts longer becomes a hold once
/// the app reports the deadline. The app feeds event timestamps in, so the
/// recognizer stays deterministic and free of timers.
public struct ModifierKeyGesture: Sendable {
    public enum Gesture: Equatable, Sendable {
        /// Short press and release on its own (only for keys that support taps).
        case tap
        /// Held past the threshold on its own.
        case holdBegan
        /// Released after `holdBegan`.
        case holdEnded
        /// Another input arrived after `holdBegan`; the hold was not meant for us.
        case holdInterrupted
    }

    public static let holdThreshold: TimeInterval = 0.3

    private enum Phase: Equatable {
        case idle
        case pressed(id: UInt64, at: TimeInterval)
        case holding
        /// The key is still down, but another input made this press not count.
        case spoiled
    }

    public let key: ModifierKey
    private var phase = Phase.idle
    private var lastID: UInt64 = 0

    public init(key: ModifierKey) {
        self.key = key
    }

    /// The key went down. Returns the press id to report back through
    /// `holdDeadlineReached(pressID:)` after `holdThreshold`, or nil if this
    /// press cannot become a gesture.
    public mutating func keyDown(at time: TimeInterval, otherModifiersHeld: Bool) -> UInt64? {
        // A second down while holding means a lost key-up; keep the hold so the
        // eventual release still ends it.
        if phase == .holding { return nil }
        guard !otherModifiersHeld else {
            phase = .spoiled
            return nil
        }
        lastID &+= 1
        phase = .pressed(id: lastID, at: time)
        return lastID
    }

    public mutating func keyUp(at time: TimeInterval) -> Gesture? {
        defer { phase = .idle }
        switch phase {
        case .pressed(_, let start):
            return key.supportsTap && time - start < Self.holdThreshold ? .tap : nil
        case .holding:
            return .holdEnded
        case .idle, .spoiled:
            return nil
        }
    }

    public mutating func holdDeadlineReached(pressID: UInt64) -> Gesture? {
        guard case .pressed(let id, _) = phase, id == pressID else { return nil }
        phase = .holding
        return .holdBegan
    }

    /// Any other key, modifier or mouse button.
    public mutating func otherInput() -> Gesture? {
        switch phase {
        case .pressed:
            phase = .spoiled
            return nil
        case .holding:
            phase = .spoiled
            return .holdInterrupted
        case .idle, .spoiled:
            return nil
        }
    }

    public mutating func reset() {
        phase = .idle
    }
}
