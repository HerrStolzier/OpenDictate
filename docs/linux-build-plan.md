# Linux-App-Plan (OpenDictate)

Stand des technischen Detailplans: 8. Oktober 2026. Phase 0 (Wegwahl) ist
über PR #16 in `main`, der Phase-1-Kern über PR #17; Übersetzung, Leiste und
Auto-Einfügen kamen mit PR #45, #47 und #51. **Phase 1 ist seit dem 5. bis
7. Oktober 2026 auf omarchy belegt** (Live-Durchstich, Fehler- und Abbruchfälle,
physischer Hotkey, Leistenanzeige), Phase 2 (Auto-Einfügen) ist Standard und
erprobt, Phase 3 (Paketierung) ist offen
([Nachweise](linux-live-2026-10-05-bis-07.md), [belegter Stand](remaining-acceptance.md#linux)).
Die nächsten Schritte stehen im Linux-Track der [ROADMAP](../ROADMAP.md#track-linux).
macOS-CI bleibt unverändert.

## Ziel (fest)

Linux-Desktop-App mit **Nutzenparität** zu macOS:

Shortcut → Aufnahme → Transkription mit **eigenem OpenAI-API-Key** → Text in der
**zuvor fokussierten** Anwendung.

v1 liefert die Zwischenablage zuverlässig. Automatisches Einfügen ist Phase 2 und
nur erlaubt, wenn dasselbe Zielfenster noch vorne ist. Kein 1:1-Port von
AppKit/Accessibility. **Linux als Ziel wird nicht aufgegeben.**

Linux ist seit dem 8. Oktober 2026 in [PROJECT.md](../PROJECT.md) als
Plattform mit belegtem Umfang geführt; der Mac-Stand in
[remaining-acceptance.md](remaining-acceptance.md) bleibt davon unberührt.

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
| v1-Pfad: Rust-Daemon/CLI plus Hyprland-Bind | Phase 1 am 5. bis 7. Oktober live auf omarchy belegt |
| Hotkey, Mic, Keyring, Clipboard auf **dieser** omarchy/Hyprland-Session | alles belegt, Hyprland-Bind Super+D seit 05.10. eingerichtet und bestätigt |
| Auto-Insert unter Wayland | Phase 2; seit 06.10. auf omarchy mit Frontmost- und Zwischenablage-Prüfung erprobt und auf Bastis Wunsch Standard; `settings insert off` für Clipboard-only |
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

Phase 0 klärte **welchen Weg** wir auf dieser Session nehmen, nicht ob Linux kommt.
Insert bewusst danach. Scheitert eine Technikvariante, wählen wir Fallback auf
dieser Session (anderer Capture-Weg, anderer Clipboard-Weg) und liefern trotzdem.
Abbruch gilt nur für eine konkrete Variante, **nicht** fürs Projekt.

## Architektur

- macOS-Swift-Code (`Sources/OpenDictate*`) bleibt unangetastet.
- Linux-Client unter `linux/` in diesem Repo: Rust-CLI `opendictate`, kein Tauri,
  kein Node/WebKit. macOS-CI bleibt Swift-only.
- `OpenDictateCore` (Swift): **Spezifikation / Orakel** — kein Link in die
  Linux-App. Pflichtpolitik in Rust nachbauen und testen (Tabelle unten), nicht
  „wo nötig“.
- API-Key und Recording-Auth nur im Keyring. Ohne Secret Service: klare Meldung,
  nie Env, Datei oder Logs. Logs ohne Key, Transkript oder Audioinhalt.

```text
linux/                 # Rust CLI, Phase-0-Pfad plus Phase-1-Kern
Sources/OpenDictate*   # macOS unverändert
docs/linux-build-plan.md
```

## Modulübersicht des Phase-1-Kerns

Diese Karte beschreibt den eingeführten Codepfad, keine Live-Abnahme:

| Datei | Rolle |
|---|---|
| `linux/src/main.rs` | CLI: Toggle, Status, Cancel, Retry, Settings, Secrets und Worker-Ablauf |
| `linux/src/record.rs` | cpal-Aufnahme, 1/90-s-Grenzen, −45-dB-Analyse, Padding und WAV-Trim |
| `linux/src/ipc.rs`, `state.rs` | Exklusiver Unix-Socket, vier Zustände und Abbruchmarker |
| `linux/src/keyring.rs` | `secret-tool`; Secret-Service-Zugriff für API-Key und Recording-Auth |
| `linux/src/clipboard.rs` | Wayland-Clipboard über `wl-copy`; Fehler ohne `WAYLAND_DISPLAY` |
| `linux/src/transcribe.rs` | HTTPS-Multipart-Upload und begrenzte Fehlerdekodierung; Offline-Stubtests |
| `linux/src/translate.rs` | Optionale Übersetzung des Transkripts über `/v1/chat/completions`; Offline-Stubtests |
| `linux/src/test_http.rs` | Gemeinsamer Loopback-HTTP-Stub nur für Tests |
| `linux/src/recovery.rs` | HMAC-SHA256, exakt authentifizierte Bytes, fünf Dateien/24 Stunden |
| `linux/src/settings.rs` | Owner-only Modell-/Sprachkonfiguration, kein Secret |
| `linux/src/window.rs` | `hyprctl activewindow -j`: nur Adresse und Klasse, kein Fenstertitel |
| `linux/src/paths.rs` | XDG runtime/state/config; geschützte Anwendungsverzeichnisse |
| `linux/hyprland.conf.example` | Beispiel-Bind; wird nicht in Nutzerkonfiguration installiert |

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
| Übersetzung | nur mit gesetzter Zielsprache; Fehler oder leere Übersetzung behalten Audio, nie stiller Rückfall auf den Originaltext |

## Phasen

### Phase 0 — Spike (Wegwahl abgeschlossen)

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
- Settings-Minimum: Key, Modell, Sprache, optionale Zielsprache für die
  Übersetzung ([Plan](linux-live-translation-plan.md)); UI deutsch wo nutzerseitig
- kein Auto-Insert; Panel öffnet nicht ungefragt während der Aufnahme
- Pflichtpolitik aus der Tabelle, mit Tests

**Done:** Manueller Durchstich auf omarchy **und** die Fälle: Fehler/Abbruch/leere
oder undelieferte Transkription behält Audio; unauthentifizierte Dateien werden
nicht hochgeladen; zweiter Start während Verarbeitung wird ignoriert; Cancel
während Upload löscht nicht die einzige Kopie; Key nie in Logs.

**Abgenommen am 5. bis 7. Oktober 2026** auf omarchy mit Bastis Go: Durchstich mit
echtem Upload, Fehlerfall mit erhaltener Aufnahme und `retry`, Abbruch und
Netzausfall während der Transkription mit erhaltener Aufnahme, kein Upload bei
Stille, physischer Hotkey Super+D, Leistenanzeige als UI-Minimum
([Nachweise](linux-live-2026-10-05-bis-07.md)). Nicht einzeln belegt und seit
dem 8. Oktober den Beta-Nutzern überlassen: Abbruch genau während der
Übersetzung, die kürzeren Zeitlimits aus PR #51.

### Phase 2 — Auto-Insert

Nur mit einer nachgewiesenen Linux-Zielregel, nicht „wenn sinnvoll“. Sie ist
bewusst strenger als der aktuelle macOS-Pfad, der die Start-App reaktiviert:

- Ziel **vor** Keyring-Dialog oder Panel erfassen (`hyprctl activewindow` oder
  gleichwertig)
- Insert nur in genau diese App und nur solange sie vorne ist
- sonst Clipboard plus klare Meldung
- Retry nie auto-insert
- Clipboard-Fallback bleibt immer

Kandidaten: `hyprctl dispatch sendshortcut`, virtuelle Tastatur. Der aktuelle
macOS-Pfad aktiviert die zu Beginn erfasste App und sendet dort ⌘V nach
Prüfung von Vordergrund und Zwischenablage. Linux braucht für Ctrl+V eine
eigene Wayland-/Hyprland-Prüfung; auch dort bleibt Insert unbestätigt und
bereits übernommener Text lässt sich nicht zurückrollen.

Wenn der Frontmost-Check nicht belegbar ist: Clipboard-only als Default, nicht
als vages Best-Effort. Auf omarchy ist er seit 06.10. erprobt; Auto-Insert ist
deshalb Standard (auch für bestehende Einstellungsdateien) und lässt sich mit
`settings insert off` abschalten.

**Done:** Ein belegter Insert-Pfad, der die Frontmost-Regel einhält, **oder**
begründeter Clipboard-only-Ship mit klarem Wayland-Status.

**Stand 06.10.2026 (auf omarchy in Einzelfällen live erprobt,
[Nachweis](linux-live-translation-plan.md)):** Das CLI erfasst beim
Start die Fensteradresse, prüft nach dem Kopieren per `hyprctl activewindow`
dieselbe Adresse und per `wl-paste` denselben Text und sendet dann über
`hyprctl dispatch` Ctrl+V (bekannte Terminals Ctrl+Shift+V) an genau diese
Adresse: zuerst als Lua-Dispatcher `hl.dsp.send_shortcut` (Hyprland 0.56 mit
Lua-Konfiguration lehnt die alte Form ab, auf omarchy am 05.10. gesehen), nach
eindeutiger Ablehnung als `sendshortcut`. Jede andere Lage endet bei der Zwischenablage mit
Hinweis; `retry` fügt nie ein; `settings insert off` schaltet es ab. Die
Leistenanzeige (`opendictate bar`, Klick: `settings target toggle`) läuft als
Befehlsmodul der Omarchy-4-Leiste oder in Waybar und deckt den Status-Teil des
UI-Minimums aus Phase 1 ab.

### Phase 3 — Packaging

- Build-Dokumentation; Arch/omarchy zuerst
- kein zweites Distro-Ziel in v1
- kein öffentliches Store-/Signatur-Publish in v1
- Linux-Checks in [CHECKS.md](../CHECKS.md) nur lokal; nicht in die macOS-CI

**Done:** Installierbarer Debug/Release-Weg auf der Zielmaschine dokumentiert.

**Stand 8. Oktober 2026:** Arch-Paket aus dem Quellcode
([PKGBUILD](../linux/packaging/arch/PKGBUILD), `makepkg -si`) und Anleitung in
[linux/README.md](../linux/README.md) liegen bereit; offline geprüft. Offen ist
die Installation auf omarchy mit einem echten Diktat (Schritt 2 im Linux-Track
der [ROADMAP](../ROADMAP.md#track-linux)). Bis dahin läuft auf Bastis Rechner
die von Hand gebaute Kopie in `~/.local/bin`.

## Risiken

- Wayland: Hotkey/Insert kompositorabhängig → Fallbacks auf dieser Session, kein
  Projektstopp
- Doppelpflege zweier Clients → Pflichtpolitik per Tabelle und Tests halten
- Linux-v1 ≠ jeder macOS-AX-Sonderpfad
- gnome-keyring auf omarchy (oft ungesperrter Login-Keyring, LUKS als Platte)
  ist schwächer als macOS-Keychain-ACLs; trotzdem Secret Service, nie Datei

## Nicht-Ziele dieses Linux-MVP

Streaming, Hold-to-talk, Windows, öffentliches Publish, macOS ersetzen,
iOS/Android, garantiertes Insert unter jedem Wayland-Compositor, X11-Session als
Nachweis, Tauri-Skeleton als Spike-Start und ein zweites Distro gehören nicht
zum beschriebenen Linux-MVP. Die plattformübergreifenden Wünsche und Stände
stehen in der [ROADMAP](../ROADMAP.md).
