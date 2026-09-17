# Development workflows

The [README](../README.md) covers the first dictation and daily behavior.
Build and test requirements are in [CHECKS.md](../CHECKS.md). The workflows below
are development tools with distinct side effects; they do not establish general
product compatibility or speech quality.

## Local build and existing daily installation

`./scripts/build-app.sh` writes `.build/OpenDictate.app`. `VERSION` controls the
marketing version and `OPENDICTATE_BUILD_NUMBER` the numeric build number.
The generated icon source is `Assets/OpenDictateIcon.png`; the build creates
`OpenDictate.icns` and also uses the source for the menu bar item.
See [local signing](accessibility-signing.md) before changing installation identity.

`./script/build_and_run.sh --daily` opens the existing
`~/Applications/OpenDictate.app`, reuses its instance and brings its daily window
forward. It refuses to start alongside a preview or another dictation build.
This launcher does not install or replace an app.

## Isolated design preview

`./script/build_and_run.sh --preview` launches `OpenDictatePreview.app` with
synthetic display states and a separate bundle identifier. It bypasses microphone,
hotkeys, Keychain, clipboard and service initialization and does not replace the
installed app. Tests on the affected Swift Testing toolchain may require the
specific plugin-path workaround documented in CHECKS.md.

## Offline integration fixtures

`--processing-focus-preview` uses fixed text and delayed processing instead of
audio/provider work. The production flow, panel, clipboard and paste policy remain
real. It waits for a disposable TextEdit document, then provides 20 seconds to
retain or change app focus. It restores the previous clipboard on normal exit if
no later clipboard change occurred. It never reads credentials or existing
recordings. Existing Accessibility permission must be current. This is not a real
dictation test.

`--matrix-fixture` and `--matrix-host` support the controlled local field tests
in the [compatibility matrix](compatibility-matrix.md). They require deliberately
prepared local fixture windows. Matrix input uses a separate test clipboard;
synthetic recordings do not use the microphone or provider. The fixture's event
count records submitted chunks, not verified characters in the destination.
Use only the existing approved local signing identity and permissions.

## Optional API-key helper

Prefer the in-app setup dialog. `./scripts/store-api-key.sh` requires the built
app, creates only a new Keychain item and restricts it to that bundle. It fails
if an item already exists. If an older helper created the item, save the key once
through the in-app dialog to recreate it under the app's access policy.

The helper prompts for the key itself. Never put the key in shell arguments or
environment variables. The in-app dialog supports paste, copy and select-all;
**API-Schlüssel anzeigen** keeps the key visible until unchecked.

Live microphone/provider work and local installation follow the current project's
authorized scope. Historical acceptance records do not supply another test budget.
