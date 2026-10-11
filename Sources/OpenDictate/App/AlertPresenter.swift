import AppKit
import Foundation
import OpenDictateCore

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
            "Namen, Fachbegriffe oder ein kurzer Kontext. Maximal 2.000 Zeichen. Diese Hinweise werden mit jedem Diktat an den Transkriptionsdienst gesendet. Leer speichern entfernt die Hinweise."
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

    struct CustomServer {
        var address: String
        var transcriptionModel: String
        var translationModel: String
    }

    /// Address and model names for a server other than OpenAI. Empty
    /// address means OpenAI; empty model fields restore the defaults.
    static func promptForCustomServer(initialValue: CustomServer) -> CustomServer? {
        let alert = NSAlert()
        alert.messageText = "Eigener Server"
        alert.informativeText =
            "Statt OpenAI kann OpenDictate jeden Server nutzen, der dieselbe Schnittstelle anbietet, auch ein "
            + "lokales Modell auf diesem Mac (zum Beispiel http://127.0.0.1:8080/v1). Ein Server auf diesem Mac "
            + "bekommt keinen API-Schlüssel. Andere Server brauchen https:// und bekommen deinen gespeicherten "
            + "Schlüssel. Leer lassen für OpenAI. Geprüft ist nur OpenAI."
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")
        func field(_ label: String, _ value: String, placeholder: String) -> (NSTextField, NSStackView) {
            let title = NSTextField(labelWithString: label)
            let input = NSTextField(string: value)
            input.placeholderString = placeholder
            input.setAccessibilityLabel(label)
            input.widthAnchor.constraint(equalToConstant: 360).isActive = true
            let row = NSStackView(views: [title, input])
            row.orientation = .vertical
            row.alignment = .leading
            row.spacing = 4
            return (input, row)
        }
        let (address, addressRow) = field(
            "Server-Adresse", initialValue.address, placeholder: "Leer = OpenAI")
        let (transcription, transcriptionRow) = field(
            "Transkriptionsmodell", initialValue.transcriptionModel,
            placeholder: TranscriptionModel.default.rawValue)
        let (translation, translationRow) = field(
            "Übersetzungsmodell", initialValue.translationModel, placeholder: Translation.defaultModel)
        let stack = NSStackView(views: [addressRow, transcriptionRow, translationRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setFrameSize(stack.fittingSize)
        alert.accessoryView = stack
        alert.window.initialFirstResponder = address
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        func trimmed(_ field: NSTextField) -> String {
            field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return CustomServer(
            address: trimmed(address), transcriptionModel: trimmed(transcription),
            translationModel: trimmed(translation))
    }

    static func promptForAPIKey(initialValue: String?) -> String? {
        let alert = NSAlert()
        alert.messageText = "OpenAI-API-Schlüssel einrichten"
        alert.informativeText =
            "Verwende deinen eigenen API-Schlüssel aus der OpenAI-Plattform. OpenAI berechnet die Transkription separat. Der Schlüssel wird im macOS-Schlüsselbund unter OpenDictate gespeichert."
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

    /// A single key needs Accessibility before it works in other apps. The
    /// current trigger stays active until the permission is there.
    static func explainMissingKeyPermission(for trigger: RecordingTrigger, keeping current: RecordingTrigger) {
        let alert = NSAlert()
        alert.messageText = "Freigabe für Bedienungshilfen fehlt"
        alert.informativeText =
            "Damit OpenDictate „\(trigger.displayName)“ in jeder App erkennt, braucht es die Freigabe für "
            + "Bedienungshilfen in den Systemeinstellungen, dieselbe wie fürs automatische Einfügen. Schalte "
            + "OpenDictate dort ein und wähle die Taste danach erneut. Bis dahin bleibt „\(current.displayName)“ aktiv."
        alert.addButton(withTitle: "Bedienungshilfen öffnen")
        alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        ModifierKeyMonitor.requestPermission()
        SystemSettings.openAccessibility()
    }
}
