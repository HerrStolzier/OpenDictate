# Plan 2: Build 8 notarisiert, finales Paket geprüft

Stand: 2. Oktober 2026. Nachweis für das finale Paket des Build-8-Kandidaten
aus dem [Build-8-Nachweis](2026-09-28-plan2-build8.md). Er deckt Plan 2,
Schritte 2 und 3 **ohne** Installation, App-Start, Migration oder Diktat ab.

## Apple-Ergebnis

- Einreichung `320efa5c-d9fa-4e3b-980b-1a121ffdd371`, eingereicht am
  28. September 2026, 17:10:08 UTC.
- Abfrage am 2. Oktober mit `xcrun notarytool info … --keychain-profile
  OpenDictate-Notary`: **Accepted**.
- [Apple-Log](2026-09-28-build8-notary-log.json): `statusSummary`
  „Ready for distribution“, `statusCode` 0, `issues` leer. Das Log nennt den
  eingereichten ZIP-SHA-256
  `cee6fcc5d7c2bc311eacbad82f1e6e7538148d1c8808fd61b18b598a0b199a82` und die
  CDHashes `e2092e18ddf04572b492f57790c383c9417a327a` (App) und
  `4083f51cf4f2f868edeb6ce8ccb3d52e5d25f83a` (Keychain-Helper).

## Ausgangsbundle

Nicht neu gebaut. Das eingereichte ZIP aus dem Build-8-Artefaktordner
`/Users/basti/.codex/artifacts/opendictate/0.1.0-build-8-b786d4c-20260928/`
hat weiterhin den SHA-256 `cee6fcc5…b199a82` und besteht `unzip -t`. Es wurde
mit `ditto -x -k` nach
`/Users/basti/.codex/artifacts/opendictate/0.1.0-build-8-b786d4c-stapled-20261002/`
entpackt. CDHashes von App und Helper stimmen mit dem Apple-Log überein.

## Ticket

```text
$ xcrun stapler staple …/OpenDictate.app
The staple and validate action worked!
$ xcrun stapler validate …/OpenDictate.app
The validate action worked!
```

Der CDHash der App blieb nach dem Anheften `e2092e18…a327a`.

## Finales Paket

`scripts/package-release-app.sh` verlangt einen sauberen Checkout genau der
Quellrevision im Bundle. Es lief daher aus einem temporären, detached
Worktree auf `b786d4ccd75462b902d3a1439c247bd1a5aeeca8`. Paketier- und
Prüfskript sind zwischen `b786d4c` und `main` unverändert. Der Worktree ist
wieder entfernt.

```text
$ scripts/package-release-app.sh …/stapled-20261002/OpenDictate.app \
    /Users/basti/.codex/artifacts/opendictate/0.1.0-build-8-b786d4c-release-20261002 K5AF446C3N
Verified Developer ID team, matching app/helper signatures, timestamps, arm64, Hardened Runtime and microphone entitlement.
The validate action worked!
…/OpenDictate.app: accepted
source=Notarized Developer ID
… (dieselben Prüfungen am entpackten Staging-ZIP bestanden)
Verified private release candidate: /Users/basti/.codex/artifacts/opendictate/0.1.0-build-8-b786d4c-release-20261002
```

- Finales ZIP (außerhalb des Repositorys):
  `/Users/basti/.codex/artifacts/opendictate/0.1.0-build-8-b786d4c-release-20261002/OpenDictate-0.1.0-build-8-arm64-b786d4ccd75462b902d3a1439c247bd1a5aeeca8.zip`
- Größe: **3.488.918 Bytes**.
- SHA-256: `2e994cd853d95fb5cf29c4da51e2ae2acd743a1867baae5151a9bd381e335768`.
- `manifest.json` daneben: Version `0.1.0`, Build `8`, `arm64`, Quellrevision
  `b786d4ccd75462b902d3a1439c247bd1a5aeeca8` (`clean`), Team `K5AF446C3N`,
  Bundle-ID `local.opendictate.app`, Executable-SHA-256
  `f1b30df17e00d97c656df61da54b1aebdab874e53eb45a69df70ae364c5727d3` und
  derselbe Archiv-SHA-256 wie oben.

## Prüfung am entpackten finalen ZIP

Das finale ZIP wurde zusätzlich in einen eigenen temporären Ordner entpackt
und unabhängig vom Paketierskript geprüft:

| Prüfung | Ergebnis |
| --- | --- |
| `codesign --verify --deep --strict --verbose=2` | `valid on disk`, `satisfies its Designated Requirement`, Helper validiert |
| Entitlements der App | nur `com.apple.security.device.audio-input` = `true` |
| `xcrun stapler validate` | `The validate action worked!` |
| `spctl --assess --type execute --verbose=2` | `accepted`, `source=Notarized Developer ID` |
| Quarantäne gesetzt (`com.apple.quarantine`, Agent Safari), danach `spctl` erneut | `accepted`, `source=Notarized Developer ID` |
| CDHash, Team, Zeitstempel | `e2092e18…a327a`, `K5AF446C3N`, 28.09.2026 17:35:01 |
| Info.plist | `0.1.0`, Build `8`, Quellrevision `b786d4c…`; `arm64` |
| SHA-256 von App-Executable und Helper | identisch mit dem Build-8-Nachweis (`f1b30df1…`, `0faffeca…`) |
| `scripts/tests/test-verify-app.sh` (Stand `b786d4c`) | 1 akzeptiert, 7 abgelehnt; Quellbundle unverändert |
| Größe des entpackten `.app` | **4.338.525 Bytes = 4,14 MiB** Dateiinhalt (4.252 KiB belegt); Ziel ≤ 8 MiB erfüllt |

Die Quarantäne-Prüfung ist eine Gatekeeper-Bewertung, kein App-Start. Der
erste Start aus dem Downloadweg ist nicht geprüft. Der temporäre Prüfordner
ist entfernt.

## Nicht Teil dieses Nachweises

Keine Installation, kein App-Start, keine Migration, kein Keychain-Zugriff,
kein Diktat und keine Veröffentlichung. Die installierte lokale App ist
unverändert. Offen für Plan 2 bleiben: erster Start des entpackten Pakets mit
Quarantäne, kontrollierter Wechsel nach der
[Migrationsanleitung](../plan2-migration.md), vollständiger Diktat- und
Kopierweg sowie der aktive Beenden-/Recovery-Fall (Plan 2, Schritte 3–5).
