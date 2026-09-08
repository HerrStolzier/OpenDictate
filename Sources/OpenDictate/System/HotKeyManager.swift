import AppKit
import Carbon
import Foundation
import OpenDictateCore

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?
    private(set) var registeredShortcut: HotKeyShortcut?
    private var activeID: UInt32 = 0

    private let registerOverride: ((HotKeyShortcut, UInt32) throws -> EventHotKeyRef)?
    private let unregisterOverride: ((EventHotKeyRef) -> Void)?

    init(
        register: ((HotKeyShortcut, UInt32) throws -> EventHotKeyRef)? = nil,
        unregister: ((EventHotKeyRef) -> Void)? = nil
    ) {
        registerOverride = register
        unregisterOverride = unregister
    }

    private func unregister(_ ref: EventHotKeyRef) {
        if let unregisterOverride { unregisterOverride(ref) } else { UnregisterEventHotKey(ref) }
    }

    deinit {
        if let hotKeyRef {
            unregister(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    /// Registers `shortcut`, replacing whatever was registered before. Safe to
    /// call repeatedly: the Carbon event handler is installed only once, so
    /// switching shortcuts does not stack up handlers.
    func register(_ shortcut: HotKeyShortcut, action: @escaping () -> Void) throws {
        if shortcut == registeredShortcut {
            self.action = action
            return
        }

        if handlerRef == nil && registerOverride == nil {
            try installEventHandler()
        }

        let nextID = activeID &+ 1
        let candidate: EventHotKeyRef
        if let registerOverride {
            candidate = try registerOverride(shortcut, nextID)
        } else {
            candidate = try registerNative(shortcut, id: nextID)
        }
        let previous = hotKeyRef
        hotKeyRef = candidate
        registeredShortcut = shortcut
        activeID = nextID
        self.action = action
        if let previous { unregister(previous) }
    }

    private func registerNative(_ shortcut: HotKeyShortcut, id: UInt32) throws -> EventHotKeyRef {
        let hotKeyID = EventHotKeyID(signature: fourCharCode("ODCT"), id: id)
        var candidate: EventHotKeyRef?
        let registrationStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &candidate
        )

        guard registrationStatus == noErr else {
            throw OpenDictateError.hotKeyRegistrationFailed(registrationStatus)
        }
        guard let candidate else { throw OpenDictateError.hotKeyRegistrationFailed(-1) }
        return candidate
    }

    private func installEventHandler() throws {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard
                    let userData,
                    let event
                else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard hotKeyID.signature == fourCharCode("ODCT") else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                guard hotKeyID.id == manager.activeID else { return noErr }
                manager.action?()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )

        guard status == noErr else {
            throw OpenDictateError.hotKeyRegistrationFailed(status)
        }
    }
}

func fourCharCode(_ value: String) -> FourCharCode {
    value.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
}
