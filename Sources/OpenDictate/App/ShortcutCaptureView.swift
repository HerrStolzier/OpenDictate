import AppKit
import OpenDictateCore

@MainActor
final class ShortcutCaptureView: NSView {
    private let label = NSTextField(labelWithString: "Tastenkombination mit ⌘, ⌥ oder ⌃ drücken")
    private(set) var shortcut: HotKeyShortcut?
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    var onNavigate: ((Bool) -> Void)?
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.frame = bounds
        label.autoresizingMask = [.width, .height]
        addSubview(label)
        setAccessibilityElement(true)
        setAccessibilityLabel("Neue Tastenkombination")
        setAccessibilityRole(.textField)
    }

    required init?(coder: NSCoder) { nil }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.intersection([.command, .control, .option]).isEmpty {
            switch event.keyCode {
            case 48:
                if let onNavigate {
                    onNavigate(flags.contains(.shift))
                } else if flags.contains(.shift) {
                    window?.selectPreviousKeyView(self)
                } else {
                    window?.selectNextKeyView(self)
                }
                return
            case 53:
                onCancel?()
                return
            case 36, 76:
                onConfirm?()
                return
            default:
                break
            }
        }
        var modifiers: UInt32 = 0
        var name = ""
        if flags.contains(.control) {
            modifiers |= HotKeyShortcut.controlMask
            name += "⌃"
        }
        if flags.contains(.option) {
            modifiers |= HotKeyShortcut.optionMask
            name += "⌥"
        }
        if flags.contains(.shift) {
            modifiers |= HotKeyShortcut.shiftMask
            name += "⇧"
        }
        if flags.contains(.command) {
            modifiers |= HotKeyShortcut.commandMask
            name += "⌘"
        }
        if event.keyCode == 49 {
            name += "Leertaste"
        } else {
            name += event.charactersIgnoringModifiers?.uppercased() ?? "Taste \(event.keyCode)"
        }
        guard
            let result = HotKeyShortcut.custom(keyCode: UInt32(event.keyCode), modifiers: modifiers, displayName: name)
        else {
            label.stringValue = "Bitte zusätzlich ⌘, ⌥ oder ⌃ verwenden"
            return
        }
        shortcut = result
        label.stringValue = name
        setAccessibilityValue(name)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self,
            !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    static func prompt() -> HotKeyShortcut? {
        let alert = NSAlert()
        alert.messageText = "Eigene Tastenkombination"
        alert.informativeText = "Die bisherige Kombination bleibt bei einem Konflikt erhalten."
        let input = ShortcutCaptureView(frame: NSRect(x: 0, y: 0, width: 400, height: 30))
        alert.accessoryView = input
        alert.addButton(withTitle: "Übernehmen")
        alert.addButton(withTitle: "Abbrechen")
        input.onConfirm = { NSApp.stopModal(withCode: .alertFirstButtonReturn) }
        input.onCancel = { NSApp.stopModal(withCode: .alertSecondButtonReturn) }
        input.onNavigate = { [weak alert, weak input] backwards in
            guard let alert, let input else { return }
            let responders: [NSResponder] = [input] + alert.buttons
            let current = responders.firstIndex { $0 === alert.window.firstResponder } ?? 0
            let next = (current + (backwards ? responders.count - 1 : 1)) % responders.count
            alert.window.makeFirstResponder(responders[next])
        }
        alert.window.initialFirstResponder = input
        // NSAlert otherwise skips buttons when full keyboard access is disabled.
        // Keep this navigation override local to this one modal window.
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak alert, weak input] event in
            let handled = MainActor.assumeIsolated {
                guard let alert, event.window === alert.window,
                    event.modifierFlags.intersection([.command, .control, .option]).isEmpty
                else { return false }
                switch event.keyCode {
                case 48: input?.onNavigate?(event.modifierFlags.contains(.shift))
                case 53: input?.onCancel?()
                case 36, 76: input?.onConfirm?()
                default: return false
                }
                return true
            }
            return handled ? nil : event
        }
        defer { if let monitor { NSEvent.removeMonitor(monitor) } }
        return alert.runModal() == .alertFirstButtonReturn ? input.shortcut : nil
    }
}
