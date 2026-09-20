# Linux-App-Plan (OpenDictate)

Stand: 20. September 2026 (finale Planfassung). **Nur Planung** — keine App-Implementierung
in diesem PR.

## Ziel (fest)

Linux-Desktop-App mit **Nutzenparität** zu macOS:

Shortcut → Aufnahme → Transkription mit **eigenem OpenAI-API-Key** → Text in der
**zuvor fokussierten** Anwendung (Zwischenablage + optional automatisches Einfügen).

Kein 1:1-Port von AppKit/Accessibility. **Linux als Ziel wird nicht aufgegeben.**

macOS bleibt das bisher belegte Produkt. `PROJECT.md` nimmt Linux erst nach
bewusster Freigabe als Produktumfang auf — **nicht** in diesem Plan-PR.
Die macOS-Abnahme in `docs/remaining-acceptance.md` bleibt unverändert und gilt
durch diesen Plan nicht als erledigt.

## Confidence / Recherchestand

| Aussage | Status |
|---|---|
| Richtung Tray-Utility, eigener Key, Clipboard-first, kein Swift-UI-Port | belastbar |
| Stack **Tauri 2 + Rust** als Arbeitshypothese | begründet, **nicht** spike-verifiziert |
| Global Hotkey, Mic, Keyring, Clipboard auf **dieser** omarchy/Wayland-Session | erst nach Spike belegt |
| Auto-Insert unter Wayland | bewusst unsicher; eigene Phase + Fallbacks |
| Packaging auf Arch/omarchy | erst in Packaging-Phase belegt |

Dieser Plan ist eine **begründete Hypothese**. Sicher wird die Wegwahl erst durch
den Spike auf der Zielmaschine.

## Stack (Arbeitshypothese)

### Alternativen

| Option | Stärken | Schwächen für OpenDictate |
|---|---|---|
| **A: Tauri 2 + Rust** | Kleines Binary; Hotkey/Clipboard/Keyring-Ökosystem; gut für Tray-Utility | Wayland-Hotkey/Insert OS-schwer; UI weniger „nativ“ als GTK |
| **B: Electron + TypeScript** | Schnelle UI; viel Tray/Clipboard-Material | Schwer; schwächere Systemnähe; größeres Supply-Chain-Thema |
| **C: Flutter (Linux)** | UI-Konsistenz | Hotkey/Keyring/Insert auf Linux oft plugin-lastig; wenig Synergie zum Swift-Repo |
| SwiftPM-App auf Linux | Core theoretisch baubar | Kein AppKit; Audio/Hotkey/Insert/Keyring trotzdem neu; Toolchain-Aufwand; hilft der Desktop-App kaum |

### Empfehlung: **Tauri 2 + Rust**

Arbeitshypothese nach Kriterien: Aufnahme-Latenz, globaler Hotkey, Clipboard,
Keyring (Secret Service, kein Key in Env/Datei/Logs), Packaging (Arch/omarchy
zuerst), Wartbarkeit **neben** unverändertem macOS-SwiftPM, schlankere
Supply-Chain als Electron.

Electron/Flutter bleiben im Plan **nachrangig dokumentiert**. Stack-Wechsel nur,
wenn der Spike eine **Technikvariante** unbrauchbar macht — nicht weil das
Linux-Produkt wackelt.

## Spike = Wegwahl, kein Produkt-No-Go

Der Spike (Phase 0) klärt **welchen Weg** wir nehmen, nicht ob Linux kommt.

Auf omarchy prüfen: Hotkey, Mikrofon, Keyring, Clipboard. **Insert bewusst danach.**

Scheitert eine Technikvariante, wählen wir Fallback — z. B. Clipboard-MVP zuerst,
anderer Hotkey-Weg (Session-Agent, X11-Session, app-fokussierter Hotkey) — und
liefern trotzdem. Abbruch gilt nur für eine konkrete Variante, **nicht** fürs Projekt.

## Architektur

- macOS-Swift-Code (`Sources/OpenDictate*`) bleibt unangetastet.
- Linux-App neu unter `linux/` (Tauri 2 + Rust).
- `OpenDictateCore` (Swift): **Spezifikation / Orakel** (Zustände, Retention,
  Modelle, Fehlerpolitik) — **kein** Link in die Linux-App. Logik in Rust
  nachziehen, wo nötig.
- API-Key nur im Keyring (Secret Service / kwallet). Logs ohne Key, Transcript
  oder Audioinhalt.

```text
linux/                 # Tauri 2 + Rust (neu)
  src-tauri/
  ui/                  # minimale UI
Sources/OpenDictate*   # macOS unverändert
docs/linux-build-plan.md
```

## Phasen

### Phase 0 — Spike (Weg klären, 1–3 Tage)

- Tauri-2-Skeleton unter `linux/`
- Hotkey, Mic → Datei, Keyring Dummy, Clipboard auf **dieser** Session
- Insert noch nicht Pflicht

**Done:** Kurzer Spike-Report mit gewähltem Weg + Fallbacks; Linux-Ziel bleibt.

### Phase 1 — MVP Clipboard-only

- Shortcut → Aufnahme → Stop → Upload (Key aus Keyring) → Clipboard + Tray/Status
- Settings: Key, Modell, Sprache, Hotkey; UI deutsch wo nutzerseitig
- Kein Auto-Insert; Panel öffnet nicht ungefragt während Aufnahme

**Done:** Manueller Durchstich auf omarchy; Key nie in Logs.

### Phase 2 — Auto-Insert (best effort)

- Ziel-App zum Start merken; Insert nur wenn sinnvoll; sonst Clipboard + klare Meldung
- X11 und Wayland getrennt und ehrlich dokumentieren; keine „jede App“-Zusage

**Done:** Mindestens ein belegter Insert-Pfad **oder** begründeter Clipboard-only-Ship
mit klarem Wayland-Status.

### Phase 3 — Packaging

- Build-Dokumentation; Arch/omarchy zuerst; optional zweites Distro-Smoke
- Kein öffentliches Store-/Signatur-Publish in v1

**Done:** Installierbarer Debug/Release-Weg auf der Zielmaschine dokumentiert.

## Risiken (ehrlich)

- Wayland: Hotkey/Insert kompositorabhängig → Fallbacks, kein Projektstopp
- Doppelpflege zweier Clients → Politik (Modelle, Retention) bewusst syncen
- Linux-v1 ≠ jeder macOS-AX-Sonderpfad

## Nicht-Ziele v1

Streaming, Hold-to-talk, Windows, öffentliches Publish, macOS ersetzen,
iOS/Android, garantiertes Insert unter jedem Wayland-Compositor.

## Offene Fragen (max. 5)

1. Clipboard-only-MVP als erster Ship akzeptabel?
2. Primärer Compositor/Desktop auf omarchy für den Spike?
3. UI-Minimum: nur Tray + kleines Panel, oder Settings wie macOS?
4. Swift-`OpenDictateCore` später unter Linux testen, oder reicht Rust-Parität?
5. Zweites Distro-Ziel neben Arch/omarchy für Phase 3?
