# Roadmap-Neuordnung · 8. Oktober 2026

Entscheidungen von Basti am 8. Oktober 2026 im Planungsthread, nach einer
Bestandsaufnahme der Plan-Dokumente und einer Nutzerrecherche. Diese Notiz
begründet die neue Ordnung von [ROADMAP](../ROADMAP.md) und
[PROJECT](../PROJECT.md); sie löst die [Neuordnung vom 2. Oktober](roadmap-neuordnung-2026-10-02.md)
als geltende Ordnung ab. Die Audio-/Recovery-Invarianten in AGENTS.md, „Apple
Silicon zuerst“ und „Zwischenablage plus ⌘V“ bleiben unverändert.

## 1. Fünf Tracks parallel statt einer Plattform zur Zeit

Linux, macOS, Windows, iOS und Android werden als eigene Tracks
vorangetrieben, weil Basti alle für eine Beta braucht. Die Regel vom
2. Oktober, nur eine Plattform aktiv zu bearbeiten und über Plattform 2 erst
nach Mac-Stufe 6 zu entscheiden, entfällt. Jeder Track hat in der ROADMAP ein
Beta-Ziel, einen Stand, nummerierte nächste Schritte und bekannte Grenzen.

## 2. Beta statt eigener Einzeltests

Einzelfall-Live-Tests (einzelne Programme, Randfälle, Sprachmischungen,
Zeitlimits) prüfen wir nicht mehr selbst, sondern lassen sie Beta-Nutzer
finden. Begründung von Basti: Ob ein Fall wirklich nötig ist und ob Nutzer
ihn so testen, wissen wir nicht; es läuft auf das Reagieren auf Rückmeldungen
hinaus. Selbst geprüft wird nur der Weg, den jeder Nutzer durchläuft:
Installation und ein echtes Diktat. Die Go-Regel für Live-Tests bleibt.

Für den Mac heißt das: Stufe 3 (sieben Tage Eigennutzung mit 20 Aufgaben)
schrumpft auf eine Eigennutzung ohne festen Messbogen; Stufe 4 behält nur
Hash, Installation/Update und übereinstimmende Produkttexte; die vollständige
UX- und VoiceOver-Prüfung wird zur bekannten Grenze der Beta. Die Stufen 5
und 6 werden zur Mac-Beta. Die Detailpläne bleiben als Kriterienquelle, mit
einem Hinweis auf diesen verkleinerten Umfang.

## 3. Preismodell

Bastis Wunsch: CLI ohne Oberfläche und mit wenigen Funktionen gratis, die
Vollversion mit Oberfläche bezahlt. Diese Fassung war nirgends schriftlich
festgehalten (geprüft: Repository, Steckbrief, Obsidian, Codex- und
Claude-Code-Verläufe auf beiden Rechnern, Projekt-Threads). Schriftlich gab es
nur die Notiz vom 12. September 2026 außerhalb des Repositorys: offener Code,
fertige App gegen Einmalzahlung, keine Aufteilung in Basis und Pro.

Entschieden am 8. Oktober (Variante „Offen, App bezahlt“): Der Code bleibt
vollständig MIT, die CLI-Builds sind gratis, die fertig installierbare,
signierte App mit Oberfläche kostet einmalig; bezahlt wird Komfort, Signatur,
Updates und Support. Die MIT-Lizenz erlaubt jedem, die volle App selbst zu
bauen; eine geschlossene Oberfläche (eigene Lizenz, zweiter Code-Teil) wurde
verworfen. Verkauf erst nach Firmengründung. Wortlaut in
[PROJECT](../PROJECT.md#preismodell).

## 4. Gaming als Anwendungsfall

Der Ursprung des Projekts, Diktieren in den Textchat von World of Warcraft,
weil es viel schneller ist als Tippen, stand bisher nur als Grund für einen
Zwei-Tasten-Shortcut in der ROADMAP. Er ist jetzt ein Anwendungsfall in
PROJECT.md mit Anforderungen (Zwei-Tasten-Kürzel, Vollbild, kein
Fensterwechsel, später Einzeltaste oder Halten-zum-Sprechen) und einem
Prüfpunkt im Windows-Track. Vor einer öffentlichen Gaming-Botschaft ist zu
klären, ob der Spielbetreiber externe Diktier-Software duldet.

## 5. Lehren aus der Nutzerrecherche (7. und 8. Oktober)

Stichproben auf Reddit zu Linux (7. Oktober, siehe die Notiz im Draft-PR #52)
und zu Windows, macOS, iOS, Android und Gaming (8. Oktober, 15 Threads;
Windows nur dünn belegt). Einzelstimmen, keine Messung; mehrere Threads
stammen von Entwicklern eigener Tools. Namen und Zitate liegen nur in den
privaten Projektunterlagen.

- Abo-Müdigkeit auf jeder Plattform; Einmalkauf wird gelobt. Stützt das
  Preismodell.
- Der eigene API-Schlüssel ist am Mac Standard (mehrere offene und bezahlte
  Apps bieten ihn), kein Alleinstellungsmerkmal. Der Unterschied muss aus
  Übersetzung, zuverlässigem Einfügen und erhaltenen Diktaten kommen.
- Verlorene Diktate und Abstürze sind der häufigste Wechselgrund. „Aufnahme
  bleibt, Wiederholung möglich“ gehört sichtbar in jede Anleitung.
- Bezahlt wird für die fertige, signierte App mit Updates und Support, auch bei
  offenem Code.
- Lokal und offline zählt auf Linux und Android mehr als auf Mac und Windows.
  Der konfigurierbare Endpunkt wird deshalb für alle Plattformen geplant.
- Nachbearbeitung (Zeichensetzung, Formatierung) gilt vielen als die
  eigentliche Qualität. OpenDictate verzichtet bewusst; die Website soll das
  erklären.
- iOS: App-Wechsel verliert die Stelle, Vollzugriff-Tastaturen schrecken ab;
  Aktionstaste plus Zwischenablage ist der gangbare Weg. Android: eigene
  Tastaturen mit Mikrofon sind erlaubt und erwünscht, mehrsprachig ohne
  Umschalten.
- Windows hat mit Voice Access eine ernst genutzte kostenlose Lösung; die
  Wechselgründe sind dieselben wie am Mac. Einfügen in Windows-Apps und
  deutsche Erkennung blieben unbelegt.
- Gaming: Die Frage nach Diktat im Spielchat kommt seit Jahren wieder; die
  genannten Lösungen sind teuer oder eingebaut, kein modernes Tool. Nutzer
  fragen, ob das als Cheat gewertet wird.

## 6. Entscheidungen festhalten

Weil die ursprüngliche Fassung des Preismodells und der Gaming-Ursprung nur im
Gespräch blieben und später nirgends auffindbar waren, gilt: Wer mit Basti
eine Produkt- oder Planungsentscheidung trifft, trägt sie in derselben Sitzung
in das Entscheidungs-Log in [PROJECT](../PROJECT.md#entscheidungen) ein und
ins Projektgedächtnis. AGENTS.md nennt die Regel.

## Umsetzung

Doku-Branch aus `main` `cdd4b7f`, Draft-PR aus dem Planungsthread. Betroffen:
`ROADMAP.md` (neu in Tracks), `PROJECT.md` (Anwendungsfälle, Preismodell,
Entscheidungs-Log), `docs/remaining-acceptance.md` (belegter Stand je
Plattform; Chronik nach `docs/archive/uebergabe-chronik-bis-2026-10-07.md`),
`docs/linux-build-plan.md` (Phase 1 abgenommen, Phase 2 Standard),
`docs/linux-live-translation-plan.md` (Nachweise nach
`docs/linux-live-2026-10-05-bis-07.md`), `docs/archive/README.md`
(Verzeichnis der datierten Berichte), `AGENTS.md` (Dokumentzuständigkeiten,
Entscheidungsregel), Hinweise in den Mac-Plänen 3 und 4. Gelöscht:
`docs/arbeitsweise-auftraege.md` (verlangte Auto-Merge ohne Rückfrage und
widersprach den Projektregeln). Kein App-Code, keine CI-Änderung.
