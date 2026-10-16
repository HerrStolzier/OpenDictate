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
        alert.messageText = count == 1 ? "Gesicherte Aufnahme löschen?" : "Gesicherte Aufnahmen löschen?"
        alert.informativeText =
            count == 1
            ? "Die gesicherte Aufnahme wird endgültig gelöscht."
            : "Die \(count) gesicherten Aufnahmen werden endgültig gelöscht."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Löschen")
        alert.addButton(withTitle: "Abbrechen")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// True when the user wants to open System Settings to load the languages.
    static func offerTranslationLanguages() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Sprachen für das Übersetzen laden"
        alert.informativeText =
            "Zum Übersetzen auf dem Mac braucht Apple die Sprachen einmal auf diesem Mac. "
            + "Lade sie unter Allgemein → Sprache & Region → Übersetzungssprachen. "
            + "Danach bleibt dein Text beim Übersetzen auf dem Mac."
        alert.addButton(withTitle: "Systemeinstellungen öffnen")
        alert.addButton(withTitle: "Später")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func confirmQuitWithActiveDictation() -> Bool {
        let alert = NSAlert()
        alert.messageText = "OpenDictate beenden?"
        alert.informativeText =
            "Ein Diktat läuft noch. Es wird abgebrochen, die Aufnahme bleibt gesichert "
            + "und du kannst sie später nochmal senden."
        alert.addButton(withTitle: "Beenden")
        alert.addButton(withTitle: "Weiterarbeiten")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func promptForVocabulary(initialValue: String?) -> String? {
        let alert = NSAlert()
        alert.messageText = "Vokabular und Kontext"
        alert.informativeText =
            "Namen und Fachbegriffe, die OpenDictate richtig schreiben soll, oder ein kurzer Kontext "
            + "(bis 2.000 Zeichen). Sie gehen bei jedem Diktat mit an den Dienst. "
            + "Speicherst du das Feld leer, sind sie gelöscht."
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

    /// Address and model names of the own server. An empty address removes
    /// it and selects OpenAI; empty model fields restore the defaults.
    static func promptForCustomServer(initialValue: CustomServer) -> CustomServer? {
        let alert = NSAlert()
        alert.messageText = "Eigener Server"
        alert.informativeText =
            "Statt OpenAI kannst du einen eigenen Server mit derselben Schnittstelle nutzen, etwa ein Modell "
            + "auf diesem Mac (http://127.0.0.1:8080/v1). Server auf diesem Mac bekommen keinen Schlüssel, "
            + "andere brauchen https:// und bekommen deinen API-Schlüssel. Die Modelle gelten nur für diesen Server. "
            + "Unter „Dienst“ wechselst du jederzeit zwischen OpenAI und deinem Server, die Adresse bleibt "
            + "gespeichert. Ohne Adresse nutzt OpenDictate OpenAI."
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

    /// Shows only the masked form of a stored key (see `APIKeyEntry`); the key
    /// itself never goes back into a text field.
    static func promptForAPIKey(stored: APIKeyEntry.Stored) -> String? {
        let alert = NSAlert()
        alert.messageText = "OpenAI-API-Schlüssel einrichten"
        alert.informativeText =
            "Füge deinen API-Schlüssel von OpenAI ein. Die Kosten rechnet OpenAI direkt mit dir ab. "
            + "Der Schlüssel bleibt im macOS-Schlüsselbund."
        switch stored {
        case .missing:
            break
        case .readable(let hint):
            alert.informativeText +=
                "\n\nGespeichert ist der Schlüssel \(hint). Lässt du das Feld leer, bleibt er unverändert."
        case .unreadable:
            alert.informativeText +=
                "\n\nIm Schlüsselbund liegt schon ein Schlüssel, OpenDictate konnte ihn aber gerade nicht lesen. "
                + "Lässt du das Feld leer, bleibt er unverändert."
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Abbrechen")

        let inputView = APIKeyInputView(
            storedHint: stored == .unreadable ? "der gespeicherte Schlüssel" : stored.hint)
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
            "Damit OpenDictate „\(trigger.displayName)“ in jeder App bemerkt, braucht es die Freigabe unter "
            + "Bedienungshilfen in den Systemeinstellungen. Schalte OpenDictate dort ein und wähl die Taste "
            + "dann nochmal. Bis dahin gilt weiter „\(current.displayName)“."
        alert.addButton(withTitle: "Bedienungshilfen öffnen")
        alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        ModifierKeyMonitor.requestPermission()
        SystemSettings.openAccessibility()
    }
}
