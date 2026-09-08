import AppKit
import OpenDictateCore

@MainActor
final class ShortcutCaptureView: NSView {
    private let label = NSTextField(labelWithString: "Tastenkombination mit ⌘, ⌥ oder ⌃ drücken")
    private(set) var shortcut: HotKeyShortcut?
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
        guard !event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
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
        alert.window.initialFirstResponder = input
        return alert.runModal() == .alertFirstButtonReturn ? input.shortcut : nil
    }
}
