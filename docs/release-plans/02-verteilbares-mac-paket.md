# Plan 2: Verteilbares Mac-Paket

**Ziel:** Ein nachvollziehbares ZIP mit einer Developer-ID-signierten,
notarisierten OpenDictate-App für Apple Silicon und macOS 14 oder neuer kann
auf dem vorhandenen Mac aus dem endgültigen Archiv normal geöffnet werden.
Es ist zunächst ein Betakandidat und wird noch nicht öffentlich angeboten.

**Voraussetzung:** [Plan 1](01-interne-produktabnahme.md) ist bestanden. Eine
geeignete Apple-Developer-Mitgliedschaft, ein geschütztes Zertifikat
`Developer ID Application` und Notarisierungszugang sind vorhanden. Die
heutige lokale selbst signierte App und die CI-Entwicklungsarchive erfüllen
diese Voraussetzung nicht.

Die internen Plan-1-Grenzen werden hier nicht als bestandene Tests ausgegeben. Vor dem Betapaket hat der Schutz vorhandener Aufnahmen und Texte Vorrang vor weiteren Feld- oder Timing-Matrizen.

## Arbeit

1. Einen getrennten Release-Bauweg für eine saubere Git-Revision schaffen.
   Version, Buildnummer, Quellrevision und `arm64` im Bundle und Manifest
   erfassen. Fehlen Developer ID, sicherer Zeitstempel, Hardened Runtime oder
   Mikrofon-Entitlement, bricht der Bau ab; ein Rückfall auf Ad-hoc-Signatur
   ist im Release-Bauweg ausgeschlossen. Private Schlüssel und
   Notarisierungsdaten bleiben außerhalb des Repositories.
2. Die App mit Developer ID signieren, als ZIP zur Apple-Notarisierung
   einreichen, deren Ergebnis und Log prüfen, das Ticket an die App heften und
   danach das endgültige ZIP erzeugen. SHA-256, Signaturteam, Version,
   Architektur und Quellrevision in ein Release-Manifest schreiben.
3. Signatur, Entitlements, Ticket und Gatekeeper-Bewertung an der **aus dem
   endgültigen ZIP entpackten** App prüfen. Den Downloadweg mit Quarantäne
   simulieren und den ersten Start des entpackten Pakets auf dem vorhandenen
   Mac prüfen. Für macOS 14 gelten nur native CI-Tests und Bundle-Build;
   eine interaktive Installation auf macOS 14 wird nicht behauptet.
4. Den Wechsel von einer älteren lokalen OpenDictate-Installation zu diesem
   Developer-ID-Build kontrolliert prüfen: bestehende Aufnahmen erhalten,
   Keychain-Zugriff und macOS-Berechtigungen tatsächlich beobachten,
   nötige erneute Freigaben verständlich dokumentieren. Danach einen
   vollständigen Diktat- und einen Zwischenablage-Lauf auf dem verteilten
   Paket prüfen.
   Keine zusätzliche Laufzeit, Hintergrund-App oder Registrierung für
   OpenDictate einführen. Den entpackten `.app`-Umfang messen; Ziel sind
   höchstens 8 MiB für den Apple-Silicon-Build (lokaler Ausgangswert:
   rund 3,9 MiB am 23. September 2026).
5. Vor der Weitergabe an Tester die noch offenen Störpfade anhand des konkreten Pakets abgleichen: Beenden während Verarbeitung so auslösen, dass der Vorgang tatsächlich aktiv ist, und neue sowie schon vorhandene Recovery-Dateien vorher und nachher prüfen. Provider- und Recorderfehler mit vorhandenen deterministischen Offline-Prüfungen absichern; tritt ein echter Fehler im begrenzten Lauf auf, dessen sichtbaren Rückweg und Dateizustand zusätzlich festhalten. Keine API-Schlüssel, Systemrechte oder alten Aufnahmen absichtlich beschädigen, um einen Fehler zu erzwingen. Ein beobachteter Datenverlust stoppt die Weitergabe.
6. Release-Bau, Prüfung und Installation in [CHECKS.md](../../CHECKS.md),
   [README.md](../../README.md) und der Entwicklerdokumentation so festhalten,
   dass die Quellrevision und das endgültige ZIP eindeutig zusammenpassen.

## Abnahme

- Das entpackte Paket besteht `codesign --verify --deep --strict`, die
  Entitlement-Prüfung, `stapler validate` und eine Gatekeeper-Bewertung.
  Das Manifest und der SHA-256-Wert beschreiben genau dieses ZIP.
- Installation des endgültigen Pakets und Wechsel vom lokalen Build
  funktionieren auf dem vorhandenen Apple-Silicon-Mac. Eventuell erneut nötige
  Berechtigungen sind sichtbar, lösbar und in der Anleitung erklärt; keine
  gespeicherte Aufnahme wird beim Wechsel überschrieben oder unbemerkt gelöscht.
- Der vollständige Diktatweg und der manuelle Kopierweg funktionieren mit
  dem entpackten Developer-ID-Build. Der tatsächlich aktive Beenden-Fall und
  die deterministischen Provider-/Recorder-Fehlerprüfungen zeigen keinen Verlust
  der einzigen Aufnahme oder eines vollständigen Textes. Ein nicht provozierter
  echter Provider-/Recorderfehler wird nicht als live bestanden bezeichnet.
  Das CI-Archiv bleibt ausdrücklich ein Entwicklungsartefakt.
- Die App bleibt ein einzelnes Bundle bis 8 MiB ohne zusätzlichen Installer,
  Hintergrunddienst oder eigenes Nutzerkonto. Der normale Diktatablauf aus
  Plan 1 bleibt durch die neue Signatur und Paketierung unverändert einfach.

**Freigabegrenze:** Erwerb oder Änderung einer Apple-Developer-Mitgliedschaft,
Zertifikats- und Schlüsselverwaltung, Notarisierungs-Upload sowie der echte
Live-Diktattest brauchen jeweils passende konkrete Autorisierung. Dieser
Plan führt nichts davon aus.

**Übergabe an [Plan 3](03-begrenzter-betatest.md):** Privater Paketlink,
Manifest, Prüfergebnisse und Installationsanleitung für die Tester.

Apple-Referenz: [Notarisierung und Voraussetzungen](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
