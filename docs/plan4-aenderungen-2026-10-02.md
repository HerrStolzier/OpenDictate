# Drei Änderungen vor dem Mac-Release (Plan 4)

Entschieden am 02.10.2026 von Basti. Grundlage: Architekturbewertung über AGENTS.md, PROJECT.md, ROADMAP.md, docs/remaining-acceptance.md und den Transcriber-Code aller drei Plattformen; Verbrauchszahlen live aus dem OpenAI-Usage-Dashboard (Default project, 01.07.–02.10.2026).

**Rahmen:** Build 8 (bei Apple zur Notarisierung) bleibt unberührt. Punkt 1 ist reine Dokumentation und kann jederzeit in `main`. Punkt 2 und der Mac-Teil von Punkt 3 gehen in den Release-Kandidaten (Plan 4), also nach dem Betatest, vor dem eingefrorenen Kandidaten. Linux-/Windows-Teile von Punkt 3 erst bei Wiederaufnahme der jeweiligen Plattform.

---

## Belegte Zahlen (OpenAI-Usage, Default project)

| Monat | gpt-transcribe | Anfragen | Kosten gpt-transcribe |
|---|---|---|---|
| Juli 2026 | 716 s | 49 | 0,054 $ |
| August 2026 | 764 s | 44 | 0,057 $ |
| September 2026 (Entwicklung/Abnahmen) | 2.802 s | 215 | 0,21 $ |
| 1.–2. Oktober | 53 s | – | ≈ 0,004 $ |
| **Summe** | **4.335 s = 72,3 min** | ≈ 310 | **≈ 0,33 $** |

- Preis bestätigt: 0,0045 $/min in allen drei Monaten (0,21 $ ÷ 46,7 min).
- Ø Diktatlänge ≈ 14 s → ≈ 0,001 $ (0,1 Cent) pro Diktat.
- Normalnutzung (Juli/August) ≈ 12 min und ≈ 0,055 $ pro Monat.
- Break-even gegen 5 $/Monat Pauschale: 1.111 min ≈ 18,5 h Sprache pro Monat.
- gpt-4o-mini-transcribe wird nach Tokens abgerechnet (Audio-Input + Text-Output), nicht pro Minute; Juli: 0,040 $ für wenige Diktate.

---

## ROADMAP-Einträge (Tabelle „Belegte künftige Erweiterungen und offene Produktfragen“)

### 1. Kostenargument und Zielgruppe schriftlich fixieren

| Feld | Inhalt |
|---|---|
| **Status** | Am 02.10. entschieden. Zielgruppe: technisch versierte Nutzer, die mit API-Schlüsseln umgehen können. Verkaufsargument: Kosten pro Nutzung statt Pauschale, plus angestrebt bessere Transkriptionsqualität als das eingebaute Diktieren (noch ohne Vergleichsmessung). Belegte Zahlen siehe oben. |
| **Nächstes nötiges Ergebnis** | `PROJECT.md`: Zielgruppe und Verkaufsargument ersetzen den Absatz „Zielgruppe, aus diesem Ablauf abgeleitet“. `README.md` und `website/index.html`: Kosten in Preis pro Minute (0,0045 $/min bei gpt-transcribe), ≈ 0,1 Cent pro Diktat, Break-even 18,5 h/Monat gegen 5 $-Pauschale; keine absolute „30 Cent“-Aussage. 90-Sekunden-Kappe pro Diktat als bewusste Produktgrenze benennen. Preisangabe für gpt-4o-mini-transcribe im Modellmenü und README als „ca.“ kennzeichnen (Token-Abrechnung). |
| **Abhängigkeit / Abschlussprüfung** | Reine Doku, kein Rebuild, kein Live-Test. Abschluss: Produkt-, Preis- und Grenzaussagen in README, PROJECT, Website identisch (AGENTS.md-Regel); Link- und Konsistenzcheck aus `CHECKS.md` bestanden. `PRIVACY.md` bleibt unverändert. |

### 2. Transkriptions-Endpunkt konfigurierbar (macOS, Plan 4)

| Feld | Inhalt |
|---|---|
| **Status** | Am 02.10. entschieden. Befund: `https://api.openai.com/v1/audio/transcriptions` steht fest in `OpenAITranscriber.request()`. Das Request-/Antwortformat ist der verbreitete Standard (Groq, Mistral, lokale Whisper-Server sprechen ihn). Nur die Adresse bindet an OpenAI. |
| **Nächstes nötiges Ergebnis** | Neues Setting `transcriptionBaseURL` in `Settings` (UserDefaults-Key, Env `OPENAI_BASE_URL` wie die OpenAI-SDKs, Default `https://api.openai.com/v1`). Request-URL = Base-URL + `/audio/transcriptions`. `TranscriptionOptions` trägt die URL; `OpenAITranscriber.request()` liest sie aus den Options, nicht aus einer Konstante. Erlaubt: `https://` beliebig, `http://` nur für `localhost`/`127.0.0.1`/`[::1]`; alles andere wird beim Speichern abgelehnt. Einstellungen → Erweitert: Textfeld neben dem API-Schlüssel, leer = Default. Startlog nennt nur den Host, nie Pfad oder Schlüssel. `OpenAIAPIErrorMessage`: deutsche Nutzertexte von „OpenAI“ auf „Der Transkriptionsdienst“ umstellen; die OpenAI-Fehlercodes bleiben als Sonderfälle erhalten. `languages[]`-Sonderfall bleibt an den Modellnamen `gpt-transcribe` gebunden. |
| **Abhängigkeit / Abschlussprüfung** | Kein Protokoll, keine Anbieterliste, keine Auto-Erkennung – nur die Adresse. Keychain-Account und Modellwahl unverändert. Offline-Tests in `TranscriptionRequestTests`: Default-URL unverändert, eigene URL landet im Request, `http://` außer Loopback wird abgelehnt. Source-Checks aus `CHECKS.md`. Ein Live-Diktat gegen die Default-URL im Plan-4-Kandidaten mit passender Freigabe; eine Fremd-URL wird nicht live abgenommen (kein Support-Versprechen). README: ein Absatz „Anderen Endpunkt verwenden“ mit dem Hinweis, dass nur OpenAI abgenommen ist. |

### 3. Ein Provider-Vertrag für Mac, Linux und Windows

| Feld | Inhalt |
|---|---|
| **Status** | Am 02.10. entschieden. Befund: Drei getrennte Implementierungen desselben Requests (Swift, Rust, C#) ohne gemeinsame Prüfgrundlage, bereits abweichend: Mac erlaubt unbekannte Modelle, Linux (`validate_model`) lehnt sie ab, Windows hat Modell fest auf `gpt-transcribe`, ohne Sprache und Prompt. |
| **Nächstes nötiges Ergebnis** | **Jetzt (Mac, Plan 4):** Ordner `fixtures/provider/` mit `CONTRACT.md` (Pfad, Multipart-Felder in Reihenfolge, Dateiname und Content-Type je Plattform, 25-MB-Grenze, Timeouts, erlaubte Statuscodes), `response-ok.json`, `error-401.json`, `error-413.json`, `error-429.json`, `error-500.json` und einer Tabelle „Statuscode → erwartete Nutzermeldung“. `TranscriptionRequestTests` und `TranscriptionTransportTests` lesen diese Dateien statt Inline-Strings. **Bei Wiederaufnahme Linux:** `validate_model` auf das Mac-Verhalten umstellen (nur `gpt-live-transcribe` ablehnen, Unbekanntes erlauben); `transcribe.rs`-Tests gegen dieselben Fixtures. **Bei Wiederaufnahme Windows:** Modell und Sprache aus Settings statt fest; `ProviderChecks` gegen dieselben Fixtures. |
| **Abhängigkeit / Abschlussprüfung** | Kein geteilter Code, nur geteilte Prüfdateien. Abschluss Mac-Teil: Fixtures vorhanden, Swift-Tests lesen sie, Offline-Checks grün, `CHECKS.md` nennt den Ordner. Abschluss gesamt: alle drei Testsuiten laufen gegen denselben Fixture-Satz. |

---

## Ergänzung PROJECT.md (Abschnitt „Ziel und Nutzen“)

Ersetzt den Satz „Zielgruppe, aus diesem Ablauf abgeleitet … Marktsegmentierung liegt hier nicht vor“:

> Zielgruppe (Entscheidung vom 2. Oktober 2026): technisch versierte Nutzer, die einen eigenen API-Schlüssel einrichten können. Verkaufsargument: Abrechnung pro gesprochener Minute statt Pauschale (belegt: 0,0045 $/min, rund 0,1 Cent pro Diktat, rund 18,5 Stunden Sprache für den Preis einer 5-$-Monatspauschale) und angestrebt bessere Transkriptionsqualität als das eingebaute Diktieren (noch ohne Vergleichsmessung). Die Zahlen stammen aus dem eigenen OpenAI-Verbrauch Juli–Oktober 2026 und sind kein Qualitätsnachweis.
