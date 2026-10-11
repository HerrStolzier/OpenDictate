import AppKit
import ApplicationServices
import OpenDictateCore

/// Watches one modifier key on its own through NSEvent monitors and reports the
/// gestures `ModifierKeyGesture` recognises. A global monitor covers other
/// apps, a local one this app's own windows. Monitors only observe: the key
/// still reaches macOS and the frontmost app. macOS delivers key events to the
/// global monitor only while the app is trusted under Accessibility.
@MainActor
final class ModifierKeyMonitor {
    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Lists OpenDictate under Accessibility and shows the macOS request.
    static func requestPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    private static let watchedEvents: NSEvent.EventTypeMask = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown
    ]

    private var gesture: ModifierKeyGesture
    private var monitors: [Any] = []
    private var deadlineTask: Task<Void, Never>?
    private let onGesture: (ModifierKeyGesture.Gesture) -> Void
    /// Called for every clean press, before any gesture; used to show that the key arrives.
    var onPress: (() -> Void)?

    var key: ModifierKey { gesture.key }

    init(key: ModifierKey, onGesture: @escaping (ModifierKeyGesture.Gesture) -> Void) {
        gesture = ModifierKeyGesture(key: key)
        self.onGesture = onGesture
    }

    /// Installs the monitors, replacing earlier ones. Returns false when AppKit
    /// refuses a monitor; nothing stays installed then.
    @discardableResult
    func start() -> Bool {
        stop()
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.watchedEvents) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.watchedEvents) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }
        guard let global, let local else {
            [global, local].compactMap { $0 }.forEach(NSEvent.removeMonitor)
            return false
        }
        monitors = [global, local]
        return true
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        deadlineTask?.cancel()
        deadlineTask = nil
        gesture.reset()
    }

    private func handle(_ event: NSEvent) {
        let result: ModifierKeyGesture.Gesture?
        if event.type == .flagsChanged, event.keyCode == key.keyCode {
            let flags = event.modifierFlags.rawValue
            if key.isPressed(rawModifierFlags: flags) {
                result = nil
                press(at: event.timestamp, otherModifiersHeld: key.otherModifiersHeld(rawModifierFlags: flags))
            } else {
                deadlineTask?.cancel()
                result = gesture.keyUp(at: event.timestamp)
            }
        } else {
            deadlineTask?.cancel()
            result = gesture.otherInput()
        }
        if let result { onGesture(result) }
    }

    private func press(at time: TimeInterval, otherModifiersHeld: Bool) {
        deadlineTask?.cancel()
        guard let id = gesture.keyDown(at: time, otherModifiersHeld: otherModifiersHeld) else { return }
        onPress?()
        deadlineTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(ModifierKeyGesture.holdThreshold)) } catch { return }
            guard let self, let result = gesture.holdDeadlineReached(pressID: id) else { return }
            onGesture(result)
        }
    }
}
