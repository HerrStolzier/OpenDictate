# Öffentliche Windows-Verteilung: Vorbereitungsplan

**Ziel:** Basti hat am 28. September 2026 Ziel B, die Vorbereitung einer
öffentlichen Verteilung, ausdrücklich gewählt. Das genehmigt Planung und
lokale, reversible Vorbereitungen. Es genehmigt keine Veröffentlichung,
Installation, Beschaffung eines Zertifikats oder echte Provider-/Mikrofonprobe.

## Technische Ausgangslage

| Bereich | Belegter Stand | Noch offen |
| --- | --- | --- |
| App | WPF und WinForms; `net10.0-windows10.0.19041.0`. Das Manifest fordert `asInvoker`. | Unterstützte Windows-Versionen und Mindestbuild festlegen und installieren/abnehmen. Das TFM allein ist keine Kompatibilitätszusage. |
| Bibliotheken und Prüfprogramme | `net10.0-windows`; gemeinsamer Kern `net10.0`. `global.json` nennt .NET SDK 10.0.401 und `latestPatch`. | Laufzeit- und Architekturmodell des öffentlichen Pakets festlegen. Architektur ist im aktuellen Projekt nicht explizit fixiert. |
| Abhängigkeiten | `NAudio.Wasapi` 3.1.0 ist direkte App-Abhängigkeit. Nullable-Prüfung, Warnungen als Fehler und `Deterministic=true` sind gesetzt. | NuGet-Abhängigkeitsgraph sperren und Build aus sauberem Checkout reproduzierbar belegen. Es gibt keine `packages.lock.json`; `Deterministic=true` beweist keine bitgleichen Artefakte. |
| Build | Auf Windows wurden App und Browser-Host mit SDK 10.0.401 ohne Warnungen oder Fehler gebaut. | `dotnet publish`, vollständige Artefaktliste, Hashprüfung und sauberen Offline-Wiederholungsbuild festlegen. |
| Installation | Kein Windows-Produktinstaller und keine öffentliche Paketdefinition vorhanden. Die Browserprobe ist nur ein getrenntes Entwicklerwerkzeug. | Installerformat, Upgrade-/Rollbackverhalten, Deinstallation und Supportpfad entscheiden. |
| Signatur | Keine Release-Signatur oder ausgewählte Signieridentität belegt. | Authenticode-Signatur, vertrauenswürdiger Zeitstempel und Verifikation des endgültigen Pakets. Zertifikatbeschaffung braucht eine eigene Freigabe. |

Die bestehende `scripts/install-browser-probe.ps1` ist kein Produktinstaller:
Sie kopiert einen Browser-Testhost in `%LOCALAPPDATA%` und registriert ihn unter
dem aktuellen Benutzer in `HKCU`. Sie verlangt einen vorbereiteten
`.source-archive-sha256`-Marker, den dieser Quellsnapshot nicht enthält. Das
Skript wurde nicht ausgeführt und bleibt außerhalb des Releasepfads.

## Releasepakete und nötige Gates

1. **Supportumfang festlegen.** Ziel-Windows-Versionen, Prozessarchitektur,
   Texteditoren und Browser ausdrücklich benennen. Die historischen Prüfungen
   belegen nur den Windows Editor und einen isolierten Chrome-Testfall des
   damaligen Kandidaten. Sie begründen keine Zusage für beliebige Editoren,
   Chromium-Browser oder Webseiten.
2. **Build reproduzierbar machen.** Sauberen Snapshot und Commit identifizieren,
   .NET SDK/Windows-Referenzpakete festlegen, NuGet-Abhängigkeiten sperren,
   Restore- und Buildkommandos dokumentieren und zwei Builds vergleichen.
   Keine ungesperrte Netzwerkwiederherstellung im abschließenden Offline-Gate.
   Manifest-, Assembly- und Produktversion müssen übereinstimmen.
3. **Paketformat auswählen.** Erst nach Support- und Laufzeitentscheidung
   zwischen frameworkabhängiger Installation und gebündelter Laufzeit sowie
   passendem Paketformat entscheiden. Einen kleinen, abhängigkeitsfreien
   Vorbereitungshelfer nur ergänzen, wenn er auf dem freigegebenen Windows-Host
   mit vorhandenem .NET-Werkzeug sinnvoll reproduzierbar läuft. Er darf weder
   einen Installer vortäuschen noch Dateien außerhalb eines neuen, ausdrücklich
   gewählten Ausgabeordners verändern.
4. **Normales Benutzerkonto abnehmen.** Saubere Erstinstallation ohne Elevation,
   Start/Stop, Tray, Tastaturbedienung, beschriftete Controls und Fehlerzustände
   prüfen. Installer, App und Deinstallation müssen im normalen Benutzerkonto
   funktionieren; eine Adminpflicht ist nicht als aktuelles Produktverhalten
   belegt.
5. **Upgrade und Entfernung sicher gestalten.** Upgrade aus jeder unterstützten
   Vorversion bei geschlossenem und laufendem Prozess kontrolliert prüfen.
   Scheitert ein Upgrade, muss die vorherige App erhalten bleiben. Aufnahme,
   Zugangsdaten, Einstellungen und Recovery dürfen nicht still gelöscht,
   migriert oder unlesbar werden. Deinstallation entfernt Programmdateien,
   löscht aber keine Nutzeraufnahmen, Wiederherstellungen oder Zugangsdaten
   ohne eine spätere ausdrücklich bestätigte Produktentscheidung.
6. **Aufnahmen und Schlüssel schützen.** Der aktuelle Quellstand schreibt
   PCM-/WAV-Originale nach `%LOCALAPPDATA%\OpenDictatePrototype\Recordings`;
   Recovery liegt separat unter `%LOCALAPPDATA%\OpenDictatePrototype\Recovery`.
   Synthetische Abläufe verwenden `SyntheticChecks` und `SyntheticRecovery`.
   Die öffentliche Aufbewahrungsregel für lokale Originale ist offen. Im
   verbundenen Ablauf wird eine geschützte
   Recoverykopie mit DPAPI erstellt, gelesen und bytegenau bestätigt; erst danach
   entfernt der Aufrufpfad die genau geöffneten Originaldateien. Die
   Credential-Manager-Integration verwendet einen festen Eintragsnamen; die
   dafür angelegten Bytepuffer werden nach Gebrauch bereinigt. Recovery
   akzeptiert nur authentifizierte WAV-Hüllen, prüft Ablauf beim Zugriff und
   behält höchstens fünf Einträge für weniger als 24 Stunden. Releaseabnahme
   muss Abbruch, leere Aufnahme,
   Schlüssel-/Speicherfehler, Strom-/Prozessabbruch, vollen Datenträger,
   Upgrade und Deinstallation einschließen. Ungültige Recoverydateien bleiben
   unangetastet; die einzige Originalaufnahme darf bei Fehlern nicht verloren
   gehen.
7. **Signieren und verifizieren.** Endgültige App und Installer mit einer
   bestätigten Windows-Code-Signing-Identität und Zeitstempel signieren.
   Falsche Identität, fehlender Zeitstempel, ungültige Signatur oder veränderte
   Hashes müssen vor Übergabe abbrechen. Kein Rückfall auf unsignierte
   öffentliche Downloads.
8. **Sichtbare Abnahme durchführen.** Installierten, signierten Kandidaten mit
   Quellcommit und Prüfsummen in einem normalen Benutzerkonto testen. Echte
   Mikrofon- und Providerläufe brauchen eine separate konkrete Freigabe für
   Audioübertragung, Kosten und Testumfang. Bis dahin bleiben die 41 Offline-
   Checks der aktuelle technische Nachweis, keine Live-Diktatabnahme.
9. **Veröffentlichung freigeben.** Erst nach allen Gates Produkttexte,
   Datenschutzhinweise, Supportumfang, Installations-/Deinstallationsanleitung,
   Downloadhashes und Websiteversion abstimmen. Öffentliche Veröffentlichung
   braucht eine zusätzliche ausdrückliche Freigabe.

## Fehlerfälle vor jedem Pakethelfer

Diese Fälle müssen vor erstem Packaging-Code als prüfbare Stopkriterien
feststehen:

- SDK, Windows-Referenzpaket oder gesperrte Abhängigkeit fehlt: abbrechen,
  nichts installieren und keinen alten Build wiederverwenden.
- Restore oder Publish schlägt fehl, meldet Warnungen oder erzeugt eine andere
  Projektmenge: kein Archiv und keine teilweise gültige Erfolgsmarke ausgeben.
- Quellcommit/Prüfsumme stimmt nicht, der Quellbaum ist geändert oder die
  erwartete Manifestversion fehlt: vor dem Packaging stoppen.
- Ausgabeverzeichnis oder Zieldatei existiert bereits: nicht überschreiben,
  löschen oder automatisch bereinigen.
- Unerwartete Datei, Symlink, `bin/`-/`obj/`-Rest, Debuglog, Secret,
  Nutzeraufnahme oder Browserprofil im Paket: Paket fail-closed verwerfen.
- Pfad enthält Leerzeichen, Unicode oder ist nicht beschreibbar; Kopie,
  Archivierung oder Extraktion ist unvollständig: keine Prüfsumme oder
  Erfolgsantwort veröffentlichen.
- Signatur, Herausgeber, Zeitstempel oder extrahierter Inhalt ist ungültig:
  keine unsignierte Ersatzdatei weitergeben.
- Installation, Upgrade, Rollback oder Entfernung würde Daten einer anderen
  Version löschen, Zugangsdaten verlieren oder Recovery unzugänglich machen:
  nichts ändern und den Test abbrechen.

Ein abhängigkeitsfreier Packaging-Schritt ist noch nicht implementiert. Erst
nach dem versionierten Basissnapshot wird geprüft, ob vorhandene .NET-Werkzeuge
auf dem Windows-Host eine klar begrenzte, wiederholbare Vorbereitung leisten.
