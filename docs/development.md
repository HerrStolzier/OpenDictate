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

## CI development archives

Successful **Swift checks** runs retain a development archive for 14 days in
[GitHub Actions](https://github.com/HerrStolzier/OpenDictate/actions/workflows/checks.yml).
Open a successful run, then download its artifact; GitHub requires a signed-in
account for artifact downloads. The artifact name identifies its source revision
and run; the app ZIP name also identifies its architecture. It contains the app
ZIP, a manifest, checksums and a short README. It is an ad-hoc development build,
not a notarized public release.

The source revision is the actual checked-out commit. In a pull-request run it
can be GitHub's synthetic merge commit; it must not be confused with the branch
head. A `main` run identifies the merged source. The manifest records
the marketing version, build number, architectures and executable/archive hashes.
The bundle itself carries `OpenDictateSourceRevision` and
`OpenDictateSourceState` in `Contents/Info.plist`.

CI packages only a clean Git checkout whose revision matches the signed bundle.
It verifies the app before packaging, extracts the ZIP into a separate temporary
directory, and repeats signature/entitlement checks plus executable hash and mode
comparison. Upload follows the source checks and controlled bundle-failure tests.

For a clean local checkout with a built ad-hoc app, the equivalent packaging
command is:

```bash
./scripts/package-ci-app.sh .build/OpenDictate.app /absolute/path/to/new-output-directory
```

The output directory must not exist. The script never installs or launches the
app. `OPENDICTATE_BUILD_NUMBER` supplies the numeric build number when building;
CI uses its workflow run number. The optional `OPENDICTATE_SOURCE_REVISION` must
be a full revision matching the current Git commit. Dirty or unversioned local
builds remain labelled as such and cannot be packaged as verified CI candidates.

The archive uses the same app bundle identifier as a local installation. Its
ad-hoc signature does not carry an existing local signing identity, so existing
Accessibility and Keychain access cannot be assumed to transfer. A downloaded
app may be blocked by Gatekeeper. Choose a deliberate local test/install procedure
before replacing a daily app; the archive does not reset permissions or bypass
macOS trust checks. Source installation with the existing local signing identity
is documented in [local signing](accessibility-signing.md).

## Linux Phase-0 spike

The crate under [`linux/`](../linux/README.md) is a Hyprland/omarchy CLI spike,
not a product build. It is absent from the macOS Swift CI workflow. On a Linux
host:

```bash
cargo test --manifest-path linux/Cargo.toml
cargo build --release --manifest-path linux/Cargo.toml
```

`opendictate toggle` records without a window. Do not put an API key on the
command line or in the environment. Live microphone, Secret Service and
clipboard checks are attended and are not implied by `cargo test`.

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

## API-key setup and older installations

Use the in-app setup dialog. `./scripts/store-api-key.sh` is a compatibility
notice only: it prints directions, exits with a nonzero status and does not read
or write the Keychain or launch the app. The shell path cannot reliably distinguish
an inaccessible legacy item from an absent one, so it does not perform migration.

Saving in the app uses `OPENAI_API_KEY_APP` in service `OpenDictate`. The older
`OPENAI_API_KEY` remains readable only while the new account is confirmed absent.
The app removes the older account after the new value is safely stored; if that
cleanup fails, the save succeeds with an explicit warning. Saving again retries
cleanup. The recovery-authentication key is separate and is not migrated.

Never put the key in shell arguments or environment variables. The in-app dialog
supports paste, copy and select-all; **API-Schlüssel anzeigen** keeps the key
visible until unchecked.

Live microphone/provider work and local installation follow the current project's
authorized scope. Historical acceptance records do not supply another test budget.
