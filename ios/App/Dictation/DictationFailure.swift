import AppIntents
import Foundation

/// Why a dictation did not end on the clipboard, with one sentence for the
/// app, the Live Activity and the Shortcuts banner. Never carries audio,
/// transcripts or keys.
enum DictationFailure: Error, Equatable {
    case microphoneNotAsked
    case microphoneDenied
    case missingAPIKey
    case invalidServerAddress
    case invalidModel
    case liveActivitiesOff
    case liveActivityFailed
    case recordingFailed
    case recordingUnreadable
    case tooShort
    case nothingRecognized
    case emptyTranslation
    case clipboardFailed
    case offline
    case invalidResponse
    /// HTTP status and the provider's error code, if it sent one.
    case service(status: Int, code: String?)

    init(_ error: Error) {
        if let failure = error as? DictationFailure {
            self = failure
        } else if error is URLError {
            self = .offline
        } else {
            self = .invalidResponse
        }
    }

    var message: String {
        switch self {
        case .microphoneNotAsked:
            L10n.pick(
                "Open OpenDictate once and allow the microphone.",
                "Öffne OpenDictate einmal und erlaube das Mikrofon.")
        case .microphoneDenied:
            L10n.pick(
                "OpenDictate may not use the microphone. Allow it in Settings → Apps → OpenDictate.",
                "OpenDictate darf das Mikrofon nicht nutzen. Erlaube es unter Einstellungen → Apps → OpenDictate.")
        case .missingAPIKey:
            L10n.pick(
                "Add your OpenAI API key in OpenDictate's settings first.",
                "Hinterlege zuerst deinen OpenAI-API-Schlüssel in den Einstellungen von OpenDictate.")
        case .invalidServerAddress:
            L10n.pick(
                "The server address in OpenDictate's settings is not valid.",
                "Die Server-Adresse in den Einstellungen von OpenDictate ist ungültig.")
        case .invalidModel:
            L10n.pick(
                "A model name in OpenDictate's settings is not valid.",
                "Ein Modellname in den Einstellungen von OpenDictate ist ungültig.")
        case .liveActivitiesOff:
            L10n.pick(
                "Live Activities are off for OpenDictate. Without them iOS stops the recording. "
                    + "Turn them on in Settings → Apps → OpenDictate.",
                "Live-Aktivitäten sind für OpenDictate aus. Ohne sie beendet iOS die Aufnahme. "
                    + "Schalte sie unter Einstellungen → Apps → OpenDictate ein.")
        case .liveActivityFailed:
            L10n.pick(
                "The Live Activity could not start, so iOS would stop the recording. Try again.",
                "Die Live-Aktivität konnte nicht starten, darum würde iOS die Aufnahme beenden. Versuche es nochmal.")
        case .recordingFailed:
            L10n.pick("The recording could not start.", "Die Aufnahme konnte nicht starten.")
        case .recordingUnreadable:
            L10n.pick("The recording could not be read.", "Die Aufnahme konnte nicht gelesen werden.")
        case .tooShort:
            L10n.pick("The recording was too short.", "Die Aufnahme war zu kurz.")
        case .nothingRecognized:
            L10n.pick("No speech was recognized.", "Es wurde keine Sprache erkannt.")
        case .emptyTranslation:
            L10n.pick("The translation came back empty.", "Die Übersetzung kam leer zurück.")
        case .clipboardFailed:
            L10n.pick(
                "The text could not be copied. Open OpenDictate to copy it.",
                "Der Text konnte nicht kopiert werden. Öffne OpenDictate, um ihn zu kopieren.")
        case .offline:
            L10n.pick("No connection to the service.", "Keine Verbindung zum Dienst.")
        case .invalidResponse:
            L10n.pick("The service sent an unexpected answer.", "Der Dienst hat unerwartet geantwortet.")
        case .service(let status, let code):
            Self.serviceMessage(status: status, code: code)
        }
    }

    /// Mirrors `OpenAIAPIErrorMessage` of the Mac app in both languages.
    private static func serviceMessage(status: Int, code: String?) -> String {
        switch code {
        case "insufficient_quota":
            return L10n.pick(
                "Your OpenAI credit or usage limit is used up. Check credit and budget in your OpenAI account.",
                "Dein OpenAI-Guthaben oder Nutzungslimit ist aufgebraucht. "
                    + "Prüfe Guthaben und Budget in deinem OpenAI-Konto.")
        case "invalid_api_key":
            return L10n.pick(
                "The OpenAI API key is not valid. Check it in OpenDictate's settings.",
                "Der OpenAI-API-Schlüssel ist ungültig. Prüfe ihn in den Einstellungen von OpenDictate.")
        case "billing_not_active":
            return L10n.pick(
                "API billing is not active. Check the billing of your OpenAI project.",
                "Die API-Abrechnung ist nicht aktiv. Prüfe die Abrechnung deines OpenAI-Projekts.")
        case "model_not_found":
            return L10n.pick(
                "The chosen model is not available at the service.",
                "Das eingestellte Modell ist beim Dienst nicht verfügbar.")
        case "rate_limit_exceeded":
            return L10n.pick(
                "Too many requests to the service. Wait a moment and try again.",
                "Zu viele Anfragen an den Dienst. Warte einen Moment und versuche es erneut.")
        default:
            break
        }
        switch status {
        case 401, 403:
            return L10n.pick(
                "The service refused access. Check the API key or your server's settings.",
                "Der Dienst hat den Zugriff abgelehnt. "
                    + "Prüfe den API-Schlüssel oder die Einstellungen deines Servers.")
        case 413:
            return L10n.pick(
                "The recording is too large for the service. Record a shorter dictation.",
                "Die Aufnahme ist für den Dienst zu groß. Nimm ein kürzeres Diktat auf.")
        case 429:
            return L10n.pick(
                "The service is not taking more requests right now. Check your credit or try again later.",
                "Der Dienst nimmt gerade keine weitere Anfrage an. "
                    + "Prüfe dein Guthaben oder versuche es später erneut.")
        case 500...599:
            return L10n.pick(
                "The service is not available right now. Try again later.",
                "Der Dienst ist gerade nicht verfügbar. Versuche es später erneut.")
        default:
            return L10n.pick(
                "The service could not process this recording.",
                "Der Dienst konnte diese Aufnahme nicht verarbeiten.")
        }
    }
}

/// Shortcuts shows this sentence when the action fails, for example after
/// "Back Tap" without network.
extension DictationFailure: CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource { "\(message)" }
}
