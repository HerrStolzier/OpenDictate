# Linux-App-Plan (OpenDictate)

Stand: 20. September 2026. Phase-0-Spike liegt unter `linux/` in diesem Repo.
Kein Produktumfang, kein Upload, macOS-CI unverändert. Die offenen Fragen sind
hier beantwortet.

## Ziel (fest)

Linux-Desktop-App mit **Nutzenparität** zu macOS:

Shortcut → Aufnahme → Transkription mit **eigenem OpenAI-API-Key** → Text in der
**zuvor fokussierten** Anwendung.

v1 liefert die Zwischenablage zuverlässig. Automatisches Einfügen ist Phase 2 und
nur erlaubt, wenn dasselbe Zielfenster noch vorne ist. Kein 1:1-Port von
AppKit/Accessibility. **Linux als Ziel wird nicht aufgegeben.**

macOS bleibt das belegte Produkt. [PROJECT.md](../PROJECT.md) nimmt Linux erst
nach bewusster Freigabe als Produktumfang auf — nicht durch diesen Plan.
Die macOS-Abnahme in [remaining-acceptance.md](remaining-acceptance.md) bleibt
unverändert und gilt durch diesen Plan nicht als erledigt.

## Entschiedene Fragen

1. **Clipboard-only als erster Ship:** ja. Recovery, Zustandsmaschine,
   authentifizierter Retry und kein paralleler Upload gehören in Phase 1.
2. **Spike-Desktop:** Hyprland mit XDPH auf dieser omarchy-Session. Kein
   X11-Umweg.
3. **UI-Minimum:** Tray plus kleines Panel auf Zuruf. Settings wie macOS erst,
   wenn Toggle, Mikrofon, Keyring und Clipboard stehen. Das Panel öffnet nie von
   selbst während der Aufnahme.
4. **Core:** Rust-Parität mit Tests, die dieselben Zahlen und Übergänge
   festnageln. Swift-`OpenDictateCore` auf Linux ist ein Plus, kein Spike-Tor.
5. **Zweites Distro:** nicht in v1. Arch/omarchy reicht für Phase 3.

## Confidence / Recherchestand

| Aussage | Status |
|---|---|
| Richtung Tray-Utility, eigener Key, Clipboard-first, kein Swift-UI-Port | belastbar |
| v1-Pfad: Rust-Daemon/CLI plus Hyprland-Bind | Spike-Code in `linux/`; Session-Nachweis im Spike-Bericht |
| Hotkey, Mic, Keyring, Clipboard auf **dieser** omarchy/Hyprland-Session | Mic, Keyring, Clipboard und fokusneutraler CLI-Toggle belegt; Hyprland-Bind nur als Beispiel |
| Auto-Insert unter Wayland | bewusst unsicher; eigene Phase; Default ist Clipboard-only |
| Packaging auf Arch/omarchy | erst in Packaging-Phase belegt |
| Tauri 2 als App-Shell | nachrangige UI-Option **nach** bewiesenem OS-Pfad |

Dieser Plan ist eine **begründete Hypothese**. Sicher wird die Wegwahl erst durch
den Spike auf der Zielmaschine.

## Stack

Die harten Teile sind Compositor, fokusneutrale Aufnahme und Secret Service,
nicht ein WebView.

| Schicht | v1-Pfad |
|---|---|
| Hotkey | Hyprland-Bind `exec, opendictate toggle` |
| Aufnahme | PipeWire/cpal in eine Datei, **ohne** Fenster; Fokus bleibt auf der Ziel-App |
| Secret | Secret Service über gnome-keyring/libsecret, fail-closed; **zwei** Secrets (API-Key und Recording-Auth) |
| Clipboard | Wayland-Clipboard (`zwlr-data-control` / `wl-clipboard`) |
| Upload | derselbe `POST /v1/audio/transcriptions`-Weg wie macOS |
| UI | erst Tray/Status; Panel nur auf Zuruf |

**Nachrangig** (kein Spike-Start, kein „grün“ ohne Hyprland-Nachweis): Tauri-2-Plugins
für Hotkey/Keyring, Electron, Flutter, X11-Session, Session-Agent, app-fokussierter
Hotkey. `tauri-plugin-global-shortcut` ist auf Hyprland oft ein No-Op.

Tauri bleibt eine **spätere UI-Option**, falls nach dem OS-Pfad wirklich ein
Settings-WebView nötig ist. Stack-Wechsel nur, wenn der Spike eine
**Technikvariante** unbrauchbar macht — nicht weil das Linux-Produkt wackelt.

In-App-Hotkey über XDPH GlobalShortcuts ist Phase-2-UX: der User bindet
`global, app:action` in Hyprland. Das ersetzt den v1-Bind `exec, opendictate toggle`
nicht.

## Spike = Wegwahl, kein Produkt-No-Go

Phase 0 klärt **welchen Weg** wir auf dieser Session nehmen, nicht ob Linux kommt.
Insert bewusst danach. Scheitert eine Technikvariante, wählen wir Fallback auf
dieser Session (anderer Capture-Weg, anderer Clipboard-Weg) und liefern trotzdem.
Abbruch gilt nur für eine konkrete Variante, **nicht** fürs Projekt.

## Architektur

- macOS-Swift-Code (`Sources/OpenDictate*`) bleibt unangetastet.
- Spike unter `linux/` in diesem Repo: Rust-CLI `opendictate`, kein Tauri,
  kein Node/WebKit. macOS-CI bleibt Swift-only.
- `OpenDictateCore` (Swift): **Spezifikation / Orakel** — kein Link in die
  Linux-App. Pflichtpolitik in Rust nachbauen und testen (Tabelle unten), nicht
  „wo nötig“.
- API-Key und Recording-Auth nur im Keyring. Ohne Secret Service: klare Meldung,
  nie Env, Datei oder Logs. Logs ohne Key, Transkript oder Audioinhalt.

```text
linux/                 # Phase-0 Rust CLI (opendictate toggle)
Sources/OpenDictate*   # macOS unverändert
docs/linux-build-plan.md
```

## Pflichtpolitik (Phase 1, mit Tests)

Zahlen und Regeln aus dem aktuellen macOS-Client. Abweichung braucht eine
bewusste Produktentscheidung, keinen stillen Skip.

| Politik | Zahl / Regel |
|---|---|
| Retention | 5 Dateien, 24 h (`RecordingRetention`) |
| Skip / Cap | 1 s Minimum, 90 s Maximum |
| Silence | −45 dB, Padding 0,25 s |
| Audio nach Fehler | Original behalten, wenn die authentifizierte Recovery-Kopie scheitert |
| Retry | nur HMAC-authentifizierte Bytes; Ablauf beim Zugriff; nie Heuristik-Skip automatisch hochladen |
| State | `idle` / `recording` / `processing` / `delivering`; kein zweiter Start während `busy` |
| Löschen nach Erfolg | nur nach erfolgreichem Clipboard-Copy (`TranscriptDelivery.canRemoveRecoveryAudio`) |
| Delivery | Clipboard immer; Retry kopiert nur (`allowPaste: false`) |
| Hotkey | Bind nur transaktional ersetzen; bei Fehler alte Bindung und Preference behalten |
| Logs | kein Key, kein Transkript, kein Audio |
| Modell | kein realtime-only (`gpt-live-transcribe`) gegen `/v1/audio/transcriptions` |

## Phasen

### Phase 0 — Spike (Weg klären, 1–3 Tage)

Auf **dieser** omarchy/Hyprland-Session, ohne Insert:

- Toggle per Hyprland-Bind startet und stoppt die Aufnahme
- vorherige App bleibt fokussiert (kein Fenster fürs Mikrofon)
- Mic schreibt eine Datei
- Secret Service liest und schreibt; ohne Dienst: klare Meldung, nie Env/Datei
- Text landet in der Zwischenablage und ist in einem nativen Wayland-Client
  einfügbar

**Nicht Done:** Skeleton kompiliert, Keyring-Dummy, Nachweis nur auf X11.

**Done:** Kurzer Spike-Report mit gewähltem Weg, was nicht ging, und Fallbacks.
Linux-Ziel bleibt. Bericht: [linux-spike-2026-09-20.md](linux-spike-2026-09-20.md).

### Phase 1 — MVP Clipboard-only

- Shortcut → Aufnahme → Stop → Upload (Key aus Keyring) → Clipboard + Tray/Status
- Settings-Minimum: Key, Modell, Sprache; UI deutsch wo nutzerseitig
- kein Auto-Insert; Panel öffnet nicht ungefragt während der Aufnahme
- Pflichtpolitik aus der Tabelle, mit Tests

**Done:** Manueller Durchstich auf omarchy **und** die Fälle: Fehler/Abbruch/leere
oder undelieferte Transkription behält Audio; unauthentifizierte Dateien werden
nicht hochgeladen; zweiter Start während Verarbeitung wird ignoriert; Cancel
während Upload löscht nicht die einzige Kopie; Key nie in Logs.

### Phase 2 — Auto-Insert

Nur mit der bestehenden macOS-Regel, nicht „wenn sinnvoll“:

- Ziel **vor** Keyring-Dialog oder Panel erfassen (`hyprctl activewindow` oder
  gleichwertig)
- Insert nur in genau diese App und nur solange sie vorne ist
- sonst Clipboard plus klare Meldung
- Retry nie auto-insert
- Clipboard-Fallback bleibt immer

Kandidaten: `hyprctl dispatch sendshortcut`, virtuelle Tastatur. Ctrl+V nach
eigenem Clipboard-Write ist eine **dokumentierte Linux-Ausnahme**, kein stilles
Cmd+V. macOS lehnt automatisches Cmd+V ab; auf Linux bleibt Insert unbestätigt
und bereits übernommener Text lässt sich nicht zurückrollen.

Wenn der Frontmost-Check nicht belegbar ist: Clipboard-only als Default, nicht
als vages Best-Effort.

**Done:** Ein belegter Insert-Pfad, der die Frontmost-Regel einhält, **oder**
begründeter Clipboard-only-Ship mit klarem Wayland-Status.

### Phase 3 — Packaging

- Build-Dokumentation; Arch/omarchy zuerst
- kein zweites Distro-Ziel in v1
- kein öffentliches Store-/Signatur-Publish in v1
- Linux-Checks in [CHECKS.md](../CHECKS.md) nur lokal; nicht in die macOS-CI

**Done:** Installierbarer Debug/Release-Weg auf der Zielmaschine dokumentiert.

## Risiken

- Wayland: Hotkey/Insert kompositorabhängig → Fallbacks auf dieser Session, kein
  Projektstopp
- Doppelpflege zweier Clients → Pflichtpolitik per Tabelle und Tests halten
- Linux-v1 ≠ jeder macOS-AX-Sonderpfad
- gnome-keyring auf omarchy (oft ungesperrter Login-Keyring, LUKS als Platte)
  ist schwächer als macOS-Keychain-ACLs; trotzdem Secret Service, nie Datei

## Nicht-Ziele v1

Streaming, Hold-to-talk, Windows, öffentliches Publish, macOS ersetzen,
iOS/Android, garantiertes Insert unter jedem Wayland-Compositor, X11-Session als
Nachweis, Tauri-Skeleton als Spike-Start, zweites Distro.
