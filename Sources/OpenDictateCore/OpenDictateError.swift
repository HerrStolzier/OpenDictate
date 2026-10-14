import Foundation

public enum OpenDictateError: LocalizedError {
    case audioPreprocessingFailed(String)
    case audioNotEligibleForUpload
    case apiError(String)
    case hotKeyRegistrationFailed(OSStatus)
    case invalidResponse
    case keychainStatus(OSStatus)
    case missingAPIKey
    case unusableTranscriptionModel
    case noActiveRecording
    case noAudioFile
    case noSpeechDetected(peakDb: Float)
    case recordingCouldNotStart
    case recordingTooShort(actual: TimeInterval, minimum: TimeInterval)
    case emptyTranslation
    case translationNotConfigured
    case invalidServerAddress

    /// User-facing messages deliberately exclude raw provider and framework errors.
    public static func userMessage(for error: Error) -> String {
        if let error = error as? OpenDictateError { return error.errorDescription ?? "Versuch es nochmal." }
        if error is URLError {
            return
                "Keine Verbindung zum Dienst. Prüf das Internet oder deinen eigenen Server und versuch es nochmal."
        }
        return "Das hat nicht geklappt. Versuch es nochmal oder öffne die Hilfe."
    }

    public var errorDescription: String? {
        switch self {
        case .audioPreprocessingFailed:
            return
                "Die Aufnahme konnte nicht vorbereitet werden. Öffne die gesicherten Aufnahmen oder starte ein neues Diktat."
        case .audioNotEligibleForUpload:
            return "Die Aufnahme ist leer oder zu groß zum Senden."
        case .apiError(let message):
            return message
        case .hotKeyRegistrationFailed:
            return "Das Tastenkürzel ist nicht verfügbar. Wähle in den Einstellungen ein anderes Kürzel."
        case .invalidResponse:
            return
                "Der Dienst hat keinen brauchbaren Text geliefert. Du kannst die Aufnahme später nochmal senden."
        case .keychainStatus:
            return "Der Schlüsselbund ist nicht zugänglich. Prüf die Zugriffsabfrage von macOS und versuch es nochmal."
        case .missingAPIKey:
            return "Der API-Schlüssel fehlt. Richte ihn über „API-Schlüssel einrichten“ "
                + "im Diktatfenster oder in den Einstellungen ein."
        case .unusableTranscriptionModel:
            return "Dieses Modell funktioniert mit OpenDictate nicht. Wähl in den Einstellungen ein anderes."
        case .noActiveRecording:
            return "Es läuft keine Aufnahme. Starte zuerst ein neues Diktat."
        case .noAudioFile:
            return "Die Aufnahme ist leer. Prüfe das Mikrofon und starte ein neues Diktat."
        case .noSpeechDetected:
            return
                "Die Aufnahme war zu leise. Prüfe das Mikrofon und sprich etwas näher hinein. Es wurde nichts gesendet."
        case .recordingCouldNotStart:
            return
                "Das Mikrofon konnte nicht gestartet werden. Prüfe den Anschluss und den Mikrofonzugriff in den Systemeinstellungen."
        case .recordingTooShort(let actual, let minimum):
            return
                "Die Aufnahme war zu kurz (\(actual.formattedSeconds)). Sprich mindestens \(minimum.formattedSeconds) lang."
        case .emptyTranslation:
            return "Die Übersetzung kam leer zurück. Der Originaltext wird nicht eingefügt."
        case .invalidServerAddress:
            return
                "Die Server-Adresse ist ungültig. Trag sie unter Einstellungen → Erweitert → Eigener Server neu ein "
                + "oder wähl unter „Dienst“ OpenAI."
        case .translationNotConfigured:
            return "Zielsprache oder Übersetzungsmodell ist ungültig. Wähle die Übersetzung in den Einstellungen neu."
        }
    }
}
