# Linux-App-Plan (OpenDictate)

Stand: 20. September 2026. **Nur Planung** — keine Implementierung in diesem Dokument.
macOS bleibt das belegte Produkt; Linux ist hier ein vorgeschlagener Parallelpfad.
Nach Freigabe müsste `PROJECT.md` den Linux-Umfang erst ausdrücklich aufnehmen.

## Ziel

Gesprochenen Text per globalem Shortcut aufnehmen, mit dem eigenen OpenAI-API-Schlüssel
transkribieren und in der zuvor fokussierten Linux-Anwendung verfügbar machen
(Zwischenablage + optional automatisches Einfügen). Nutzenparität zu macOS,
kein 1:1-Port von AppKit/Accessibility.

## Stack-Entscheidung

### Alternativen

| Option | Stärken | Schwächen für OpenDictate |
|---|---|---|
| **A: Tauri 2 + Rust** (UI: WebView leicht / oder schlankes HTML) | Kleines Binary; `global-hotkey`, `arboard`, `keyring`; guter Fit für Tray-Utility; klare Trennung Shell vs. Logik | Wayland-Hotkey/Insert bleibt OS-schwer; UI weniger „nativ“ als GTK |
| **B: Electron + TypeScript** | Schnelle UI; viel Clipboard-/Tray-Ökosystem | Schwer; schwächere Systemintegration; größeres Supply-Chain-/Update-Thema |
| **C: Flutter (Linux)** | Gute UI-Konsistenz | Global Hotkey, Keyring, Insert in Fremd-Apps auf Linux schwächer / mehr Plugins; wenig Synergie zum Swift-Repo |
| (verworfen) SwiftPM-App auf Linux | `OpenDictateCore` könnte theoretisch mit Swift-Linux gebaut werden | Kein AppKit; Audio/Hotkey/Insert/Keyring trotzdem neu; Toolchain auf Arch/omarchy aufwendig; hilft der Desktop-App kaum |

### Empfehlung: **Tauri 2 + Rust**

**Begründung (Kriterien):**

1. **Aufnahme / Latenz:** Native Capture (z. B. `cpal` / PipeWire-fähig) ohne Electron-Runtime.
2. **Global Hotkey:** Rust-Crates + Distro-Fallbacks; ehrlich als Spike-Risiko unter Wayland führen.
3. **Clipboard:** Robust und ausreichend für MVP (verlustfreier manueller Rückweg, analog macOS).
4. **Auto-Insert:** Schwerster Teil — X11 (`xdotool`/XTST) vs. Wayland (Portal/Accessibility, oft unmöglich ohne Kompositor-Hilfe). Tauri zwingt uns nicht zu falscher Sicherheit; Insert bleibt eigene Phase.
5. **Keyring:** `keyring`-crate → Secret Service / kwallet — entspricht der macOS-Keychain-Invariante (kein Key in Env/Datei/Logs).
6. **Packaging:** `.deb`/Arch-`PKGBUILD`/AppImage machbar; Ziel zuerst **Arch/omarchy**, zweites Smoke-Ziel z. B. Ubuntu LTS.
7. **Wartbarkeit neben SwiftPM:** macOS-Code unangetastet; Linux unter `linux/` (Monorepo). `OpenDictateCore` (Swift) wird **nicht** in die Linux-App gelinkt — Wiederverwendung als **Spezifikation** (Zustände, Retention, Modelle, Fehlertexte/Politik), Logik in Rust nachgezogen oder dünn gehalten.
8. **Lizenz / Supply-Chain:** Weniger JS-Transitivität als Electron; Rust-Lockfile reviewbar.

Electron nur wählen, wenn UI-Geschwindigkeit wichtiger ist als Binary-Größe und Systemnähe.
Flutter nicht empfohlen für dieses Tray/Hotkey-Produkt.

## Was aus OpenDictateCore wiederverwendbar ist

| Bereich | Wiederverwendung |
|---|---|
| Zustandsmodell, Outcomes, Retention-Politik, Modellliste, Trim-/Level-Politik, Fehlerklassen | **Konzepte / Tests als Orakel** — in Rust nachbilden, wo sinnvoll |
| Swift-Quellen selbst | **Nicht** in der Linux-App; optional später Linux-CI nur für Core-Tests, falls Swift-Toolchain bewusst eingeführt wird |
| Audio-Capture, Hotkey, Insert, Keychain/Keyring, UI | **Neu** (plattformspezifisch) |
| OpenAI-Upload-Vertrag | Neu in Rust, Verhaltensparität zu macOS-Client (gleiche Modelle/Limits laut Settings-Politik) |

## Phasen

### Phase 0 — Spike (1–3 Tage)

- Tauri-2-Skeleton unter `linux/`
- Nachweis: Global Hotkey auf **dieser** omarchy/Wayland-Session (oder dokumentierter Fallback: nur X11 / nur App-fokussierter Hotkey)
- Mikrofon-Capture → WAV/Temp-Datei; Keyring set/get (Dummy-Secret)
- Clipboard schreiben

**Done:** Kurzer Spike-Report in PR/Issue; Go/No-Go für Hotkey+Capture auf Zielmaschine.

### Phase 1 — MVP Clipboard-only

- Shortcut → aufnehmen → stoppen → Upload mit Key aus Keyring → Text in Clipboard + Tray/Panel-Status
- Settings: Key, Modell, Sprache, Hotkey; deutsche UI-Texte wo nutzerseitig
- Kein Auto-Insert; Panel öffnet nicht ungefragt während Aufnahme (Parität zur macOS-Korrektur)

**Done:** Ein manueller Durchstich auf omarchy mit unkritischem Testsatz; Key nie in Logs.

### Phase 2 — Auto-Insert (best effort)

- Fokus-App zum Start merken; Insert nur wenn noch sinnvoll; sonst Clipboard-Fallback mit klarer Meldung
- X11-Pfad und Wayland-Grenzen getrennt dokumentieren; keine pauschale „jede App“-Zusage

**Done:** Mindestens eine belegte X11-App + ehrlicher Wayland-Status; Abbruch/Focus-Verlust getestet.

### Phase 3 — Packaging

- Debug-Build-Skript; Arch-Paket oder dokumentierte `cargo tauri build`-Schritte
- Kein Public Publish/Notarize-Äquivalent in v1

**Done:** Zweite Maschine/Distro Smoke oder klar „nur Arch/omarchy belegt“.

## Risiken

- **Wayland:** Global Shortcuts und Insert sind kompositorabhängig; Spike kann MVP auf Clipboard+manuellen Hotkey-Fallback reduzieren.
- **Privacy:** Nur Secret Service; keine `.env`; Logs ohne Key/Transcript/Audioinhalt (macOS-Invariante).
- **Doppelpflege:** Zwei Clients — Politikänderungen (Modelle, Retention) bewusst syncen.
- **Erwartung:** Linux-v1 ≠ Feature-Parität zu jedem macOS-AX-Sonderpfad (Terminal, Browser-Unicode, …).

## Nicht-Ziele v1

Streaming, Hold-to-talk, Windows, öffentliches Store-/Signatur-Publish, Ersetzen der macOS-App,
iOS/Android, garantiertes Insert unter jedem Wayland-Compositor.

## Repo-Layout (Vorschlag)

```text
linux/                 # Tauri 2 + Rust (neu)
  src-tauri/
  ui/                  # minimale UI
Sources/OpenDictate*   # macOS unverändert
docs/linux-build-plan.md
```

Kein Zwang, Swift-Targets jetzt multipplattform zu machen.

## PROJECT.md nach Freigabe

Wenn Basti Linux als Produktumfang will: in `PROJECT.md` unter Umfang/Grenzen einen
kurzen Linux-Absatz + Verweis auf diesen Plan; offene Entscheidung „Windows-/Linux-Umfang“
entsprechend anpassen. **Nicht** in diesem Plan-PR.

## Offene Fragen an Basti (max. 5)

1. Ist **Clipboard-only-MVP** akzeptabel, falls Wayland-Insert/Hotkey im Spike scheitert?
2. Primärer Compositor/Desktop auf omarchy (für Spike-Fokus)?
3. UI-Minimum: nur Tray + kleines Panel, oder Settings-Fenster wie macOS?
4. Soll Swift-`OpenDictateCore` später zusätzlich unter Linux getestet werden, oder reicht Rust-Parität?
5. Zweites Distro-Ziel neben Arch/omarchy für Phase 3?
