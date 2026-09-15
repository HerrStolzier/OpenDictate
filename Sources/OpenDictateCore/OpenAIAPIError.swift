import Foundation

public enum OpenAIAPIErrorMessage {
    struct Body: Decodable {
        let error: Detail
    }

    struct Detail: Decodable {
        let message: String?
        let type: String?
        let code: String?
    }

    public static func humanReadableMessage(from data: Data, statusCode: Int) -> String {
        let fallback: String
        switch statusCode {
        case 401, 403:
            fallback = "OpenAI hat den Zugriff abgelehnt. Prüfe den API-Schlüssel unter Einstellungen → Erweitert."
        case 413:
            fallback = "Die Aufnahme ist für OpenAI zu groß. Nimm ein kürzeres Diktat auf."
        case 429:
            fallback =
                "OpenAI nimmt gerade keine weitere Anfrage an. Prüfe dein Guthaben oder versuche es später erneut."
        case 500...599:
            fallback = "OpenAI ist gerade nicht verfügbar. Versuche es später erneut."
        default:
            fallback = "OpenAI konnte diese Aufnahme nicht verarbeiten. Versuche ein neues Diktat oder öffne die Hilfe."
        }
        guard let body = try? JSONDecoder().decode(Body.self, from: data) else { return fallback }
        switch body.error.code ?? body.error.type {
        case "insufficient_quota":
            return
                "Dein OpenAI-Guthaben oder Nutzungslimit ist aufgebraucht. Prüfe Guthaben und Budget in deinem OpenAI-Konto."
        case "invalid_api_key":
            return
                "Der OpenAI-API-Schlüssel ist ungültig. Prüfe ihn unter Einstellungen → Erweitert → API-Schlüssel einrichten."
        case "billing_not_active":
            return "Die API-Abrechnung ist nicht aktiv. Prüfe die Abrechnung deines OpenAI-Projekts."
        case "rate_limit_exceeded":
            return "Zu viele Anfragen an OpenAI. Warte einen Moment und versuche es erneut."
        default:
            return fallback
        }
    }
}
