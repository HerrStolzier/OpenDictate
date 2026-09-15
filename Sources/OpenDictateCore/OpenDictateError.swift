import Foundation

public enum OpenDictateError: LocalizedError {
    case audioPreprocessingFailed(String)
    case apiError(String)
    case hotKeyRegistrationFailed(OSStatus)
    case invalidResponse
    case keychainStatus(OSStatus)
    case missingAPIKey
    case noActiveRecording
    case noAudioFile
    case noSpeechDetected(peakDb: Float)
    case recordingCouldNotStart
    case recordingTooShort(actual: TimeInterval, minimum: TimeInterval)

    public var isSkippedRecording: Bool {
        switch self {
        case .noSpeechDetected, .recordingTooShort:
            return true
        default:
            return false
        }
    }

    /// User-facing messages deliberately exclude raw provider and framework errors.
    public static func userMessage(for error: Error) -> String {
        if let error = error as? OpenDictateError { return error.errorDescription ?? "Bitte versuche es erneut." }
        if error is URLError {
            return "OpenAI ist gerade nicht erreichbar. Prüfe die Internetverbindung und versuche es später erneut."
        }
        return "Der Vorgang konnte nicht abgeschlossen werden. Versuche es erneut oder öffne die Hilfe."
    }

    public var errorDescription: String? {
        switch self {
        case .audioPreprocessingFailed:
            return
                "Die Aufnahme konnte nicht vorbereitet werden. Öffne die aufbewahrten Aufnahmen oder versuche ein neues Diktat."
        case .apiError(let message):
            return message
        case .hotKeyRegistrationFailed:
            return "Das Tastenkürzel ist nicht verfügbar. Wähle in den Einstellungen ein anderes Kürzel."
        case .invalidResponse:
            return "OpenAI hat keinen verwendbaren Text geliefert. Versuche die Aufnahme später erneut zu verarbeiten."
        case .keychainStatus:
            return "Der Schlüsselbund ist nicht zugänglich. Prüfe die Zugriffsabfrage von macOS und versuche es erneut."
        case .missingAPIKey:
            return "Der API-Schlüssel fehlt. Richte ihn unter Einstellungen → Erweitert ein."
        case .noActiveRecording:
            return "Es läuft keine Aufnahme. Starte zuerst ein neues Diktat."
        case .noAudioFile:
            return "Die Aufnahme konnte nicht gespeichert werden. Prüfe das Mikrofon und starte ein neues Diktat."
        case .noSpeechDetected:
            return
                "Die Aufnahme war zu leise. Prüfe das Mikrofon und sprich etwas näher hinein. Es wurde nichts an OpenAI gesendet."
        case .recordingCouldNotStart:
            return
                "Das Mikrofon konnte nicht gestartet werden. Prüfe den Anschluss und den Mikrofonzugriff in den Systemeinstellungen."
        case .recordingTooShort(let actual, let minimum):
            return
                "Die Aufnahme war zu kurz (\(actual.formattedSeconds)). Sprich mindestens \(minimum.formattedSeconds) und beende dann die Aufnahme."
        }
    }
}
