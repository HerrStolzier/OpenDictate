import AppKit
import Foundation

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
        alert.messageText = "Set OpenAI API Key"
        alert.informativeText = "The key is stored in your macOS Keychain under the OpenDictate service."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let inputView = APIKeyInputView(initialValue: initialValue)
        alert.accessoryView = inputView

        guard alert.runModal() == .alertFirstButtonReturn else {
            return .cancelled
        }

        let key = inputView.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? .empty : .key(key)
    }
}
