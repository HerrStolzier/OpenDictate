import AppKit
import Foundation

/// Every modal the app shows, in one place. Each call blocks on `runModal()`
/// exactly like the inline versions it replaces.
@MainActor
enum AlertPresenter {
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

    static func confirmQuitWithActiveDictation() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Aktives Diktat sichern und beenden?"
        alert.informativeText =
            "Die laufende Arbeit wird abgebrochen. Die Aufnahme bleibt zur manuellen Wiederholung erhalten."
        alert.addButton(withTitle: "Sichern und beenden")
        alert.addButton(withTitle: "Weiterarbeiten")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func promptForVocabulary(initialValue: String?) -> String? {
        let alert = NSAlert()
        alert.messageText = "Vokabular und Kontext"
        alert.informativeText =
            "Namen, Fachbegriffe oder ein kurzer Kontext. Maximal 2.000 Zeichen. Diese Hinweise werden mit jedem Diktat an OpenAI gesendet. Leer speichern entfernt die Hinweise."
        let field = NSTextField(wrappingLabelWithString: "")
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.drawsBackground = true
        field.frame = NSRect(x: 0, y: 0, width: 440, height: 90)
        field.stringValue = initialValue ?? ""
        field.setAccessibilityLabel("Vokabular und Kontext")
        alert.accessoryView = field
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func promptForAPIKey(initialValue: String?) -> String? {
        let alert = NSAlert()
        alert.messageText = "OpenAI-API-Schlüssel einrichten"
        alert.informativeText = "Der Schlüssel wird im macOS-Schlüsselbund unter OpenDictate gespeichert."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")

        let inputView = APIKeyInputView(initialValue: initialValue)
        alert.accessoryView = inputView

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        return inputView.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
