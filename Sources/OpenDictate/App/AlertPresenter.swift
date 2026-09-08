import AppKit
import Foundation
import OpenDictateCore

/// Every modal the app shows, in one place. Each call blocks on `runModal()`
/// exactly like the inline versions it replaces.
@MainActor
enum AlertPresenter {
    enum APIKeyPromptResult {
        case cancelled
        case empty
        case key(String)
    }

    static func showWarning(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    static func confirmDeleteSavedRecordings(count: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Gespeicherte Aufnahmen löschen?"
        alert.informativeText = "Damit werden \(count) aufbewahrte Aufnahme(n) endgültig gelöscht."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Löschen")
        alert.addButton(withTitle: "Abbrechen")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Shown when the transcript reached the clipboard but Cmd+V could not be
    /// simulated. Returns to the caller after the user dismisses it.
    static func showAccessibilityRequired() {
        let alert = NSAlert()
        alert.messageText = "Text copied, but OpenDictate cannot paste yet"
        alert.informativeText = """
        macOS is blocking automatic paste. OpenDictate needs Accessibility permission to send Cmd+V into the app you were using.

        Grant access in Privacy & Security > Accessibility, then try dictating again.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            SystemSettings.openAccessibility()
        }
    }

    static func showBluetoothInputWarning(deviceName: String) {
        let alert = NSAlert()
        alert.messageText = "No speech detected from \(deviceName)"
        alert.informativeText = """
        OpenDictate recorded, but the audio was (near) silent, so nothing was sent for transcription.

        Your microphone is currently set to \(deviceName), a Bluetooth device. Bluetooth headset mics often deliver almost no signal. Switch the input to the built-in microphone in Sound settings, then try dictating again.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Sound Settings")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            SystemSettings.openSound()
        }
    }

    static func promptForAPIKey(initialValue: String?) -> APIKeyPromptResult {
        let alert = NSAlert()
        alert.messageText = "OpenAI-API-Schlüssel einrichten"
        alert.informativeText = "Der Schlüssel wird im macOS-Schlüsselbund unter OpenDictate gespeichert."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")

        let inputView = APIKeyInputView(initialValue: initialValue)
        alert.accessoryView = inputView

        guard alert.runModal() == .alertFirstButtonReturn else {
            return .cancelled
        }

        let key = inputView.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? .empty : .key(key)
    }
}
