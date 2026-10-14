# Öffentliche Windows-Verteilung: Vorbereitungsplan

**Ziel:** Basti hat am 28. September 2026 Ziel B, die Vorbereitung einer
öffentlichen Verteilung, ausdrücklich gewählt. Das genehmigt Planung und
lokale, reversible Vorbereitungen. Es genehmigt keine Veröffentlichung,
Installation, Beschaffung eines Zertifikats oder echte Provider-/Mikrofonprobe.

## Technische Ausgangslage

| Bereich | Belegter Stand | Noch offen |
| --- | --- | --- |
| App | WPF und WinForms; `net10.0-windows`, nur x64. Das Manifest fordert `asInvoker`. | Unterstützte Windows-Versionen und Mindestbuild festlegen und installieren/abnehmen. Das TFM allein ist keine Kompatibilitätszusage. |
| Bibliotheken und Prüfprogramme | `OpenDictate.Windows` und der Schutzprüfer `net10.0-windows`; Kern, Provider und Offline-Prüfungen `net10.0`. `global.json` nennt .NET SDK 10.0.401 und `latestPatch`. | Laufzeitmodell des öffentlichen Pakets festlegen (mitgelieferte Laufzeit oder vorausgesetzte). |
| Abhängigkeiten | `NAudio.Wasapi` 3.1.0 ist direkte App-Abhängigkeit. Nullable-Prüfung, Warnungen als Fehler und `Deterministic=true` sind gesetzt. | NuGet-Abhängigkeitsgraph sperren und Build aus sauberem Checkout reproduzierbar belegen. Es gibt keine `packages.lock.json`; `Deterministic=true` beweist keine bitgleichen Artefakte. |
| Build | Die Beta-App baut auf Linux und im Windows-Job der CI ohne Warnungen; auf einem Windows-PC wurde sie noch nicht gebaut. | `dotnet publish`, vollständige Artefaktliste, Hashprüfung und sauberen Offline-Wiederholungsbuild festlegen. |
| Installation | Kein Windows-Produktinstaller und keine öffentliche Paketdefinition vorhanden. | Installerformat, Upgrade-/Rollbackverhalten, Deinstallation und Supportpfad entscheiden. |
| Signatur | Keine Release-Signatur oder ausgewählte Signieridentität belegt. | Authenticode-Signatur, vertrauenswürdiger Zeitstempel und Verifikation des endgültigen Pakets. Zertifikatbeschaffung braucht eine eigene Freigabe. |

## Releasepakete und nötige Gates

1. **Supportumfang festlegen.** Ziel-Windows-Versionen und Prozessarchitektur
   ausdrücklich benennen. Eingefügt wird über Zwischenablage und Strg+V in das
   Fenster, das beim Start vorne war; daraus folgt keine Zusage für beliebige
   Programme oder Spiele. In Programme mit Adminrechten lässt Windows nicht
   einfügen; die App erkennt das nicht, der Text bleibt in der Zwischenablage.
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
6. **Aufnahmen und Schlüssel schützen.** Die Beta-App schreibt
   PCM-/WAV-Originale nach `%LOCALAPPDATA%\OpenDictate\Recordings` und die
   Recovery nach `%LOCALAPPDATA%\OpenDictate\Recovery`. Synthetische Abläufe
   verwenden `SyntheticChecks` und `SyntheticRecovery`.
   Das Transkript liegt nach jedem Diktat in der Zwischenablage von Windows und
   bis zum Beenden im Speicher der App für „Letzten Text kopieren“. Die App
   markiert es so, dass Windows es nicht in den Zwischenablageverlauf und nicht
   in die Cloud-Zwischenablage übernimmt; ein Programm, das die Zwischenablage
   selbst mitliest, kann es trotzdem sehen.
   Einstellungen (Modell, Sprache, Übersetzung, Server-Adresse) liegen ohne
   Geheimnis in `%APPDATA%\OpenDictate\settings.json`. Die Aufnahme geht an
   OpenAI oder an den eingetragenen eigenen Server; ist eine Übersetzung
   eingestellt, geht danach das Transkript an denselben Server. Ein Server auf
   diesem Computer bekommt keinen Schlüssel.
   Ein Original, das nach einem Absturz oder einer gescheiterten Sicherung
   im Aufnahmeordner liegen bleibt, löscht die App beim nächsten Start, sobald
   es 24 Stunden alt ist; nur Ordner mit ausschließlich eigenen Journaldateien,
   jede Datei über einen geprüften, exklusiven Handle. Im
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
   Audioübertragung, Kosten und Testumfang. Bis dahin bleiben die Offline-
   Checks (siehe [README](README.md#beta-app-11-oktober-2026)) der aktuelle
   technische Nachweis, keine Live-Diktatabnahme.
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
