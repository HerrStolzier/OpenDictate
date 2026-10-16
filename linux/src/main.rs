mod clipboard;
mod i18n;
mod insert;
mod ipc;
mod keyring;
mod notify;
mod paths;
mod policy;
mod record;
mod recovery;
mod server;
mod settings;
mod setup;
mod shortcut;
mod state;
mod transcribe;
mod translate;
mod waybar;
mod window;

#[cfg(test)]
mod test_http;
#[cfg(test)]
mod test_support;

use std::fs::{self, File, OpenOptions};
use std::io::{self, IsTerminal, Read, Write};
use std::os::unix::fs::OpenOptionsExt;
use std::os::unix::io::AsRawFd;
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use ipc::Event;

const CLIPBOARD_SPIKE_DE: &str = "OpenDictate: Zwischenablage ok.";
const CLIPBOARD_SPIKE_EN: &str = "OpenDictate: clipboard ok.";
const USAGE_DE: &str = "\
opendictate — Diktieren für Hyprland (Beta)

Zum Start: `opendictate setup` richtet Schlüssel oder eigenen Server und das
Kürzel ein.

Befehle:
  setup                  geführte Einrichtung: Dienst und Kürzel
  toggle                 Diktat starten oder beenden
  status                 Zustand (idle, starting, recording, processing, delivering)
  bar                    Status als JSON-Zeile für Omarchy-Leiste oder Waybar
  cancel                 Aufnahme oder Verarbeitung sicher abbrechen
  retry                  letzte gesicherte Aufnahme nochmal senden
  retry --openai         letzte gesicherte Aufnahme ausdrücklich einmal an OpenAI senden
  retry --skipped        letzte zu kurze oder stille Aufnahme trotzdem senden
  copy-status            festen Statustext in die Zwischenablage
  secrets probe          Schlüsselbund prüfen: schreiben, lesen, löschen
  secrets status         zeigt, ob API-Schlüssel und Sicherungsschlüssel da sind
  secrets set-api-key    API-Schlüssel über stdin speichern (kein Argument)
  secrets init-auth      Sicherungsschlüssel (für gesicherte Aufnahmen) anlegen
  settings show          Modell, Sprache und Übersetzung anzeigen
  settings model NAME    Modell für die Abschrift setzen
  settings language CODE Sprache setzen; `auto` für Erkennung
  settings target CODE   Übersetzen in Zielsprache, z. B. `en`; `off` aus
  settings target toggle Übersetzung aus- oder mit letzter Zielsprache einschalten
  settings insert on|off automatisch ins Fenster einfügen, in dem du gestartet hast
  settings translation-model NAME  Modell für die Übersetzung setzen
  settings server URL    Eigener Server: Server-Adresse inkl. /v1; `off` = OpenAI
  shortcut status        Kürzel und freie Tasten anzeigen
  shortcut set KÜRZEL    super-d, f9 oder right-alt in die Hyprland-Konfiguration
  version                Version anzeigen
";
const USAGE_EN: &str = "\
opendictate — dictation for Hyprland (beta)

To begin: `opendictate setup` sets up your key or custom server and the
shortcut.

Commands:
  setup                  guided setup: service and shortcut
  toggle                 start or stop a dictation
  status                 state (idle, starting, recording, processing, delivering)
  bar                    status as a JSON line for the Omarchy bar or Waybar
  cancel                 safely cancel a recording or processing
  retry                  send the last kept recording again
  retry --openai         explicitly send the last kept recording to OpenAI once
  retry --skipped        send the last too short or silent recording anyway
  copy-status            put a fixed status text in the clipboard
  secrets probe          check the keyring: write, read, delete
  secrets status         whether the API key and the key for kept recordings exist
  secrets set-api-key    store the API key from stdin (no argument)
  secrets init-auth      create the key for kept recordings if it is missing
  settings show          show model, language and translation
  settings model NAME    set the transcription model
  settings language CODE set the spoken language; `auto` to detect it
  settings target CODE   translate into a language, e.g. `en`; `off` to stop
  settings target toggle turn translation off, or on with the last language
  settings insert on|off paste the text into the window you started in
  settings translation-model NAME  set the model for translation
  settings server URL    custom server: server address incl. /v1; `off` = OpenAI
  shortcut status        show the shortcut and which keys are free
  shortcut set KEY       write super-d, f9 or right-alt into the Hyprland config
  version                show the version
";

fn main() {
    match run(std::env::args().skip(1).collect()) {
        Ok(()) => {}
        Err(message) => {
            eprintln!("{message}");
            std::process::exit(1);
        }
    }
}

fn run(args: Vec<String>) -> Result<(), String> {
    match args
        .iter()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .as_slice()
    {
        [] | ["help"] | ["-h"] | ["--help"] => {
            print!("{}", i18n::t(USAGE_DE, USAGE_EN));
            Ok(())
        }
        ["version"] | ["--version"] => {
            println!("opendictate {}", env!("CARGO_PKG_VERSION"));
            Ok(())
        }
        ["setup"] => setup::run(),
        ["shortcut", "status"] => shortcut_status(),
        ["shortcut", "set", id] => shortcut_set(id),
        ["toggle"] => toggle(),
        ["status"] => status(),
        ["bar"] | ["waybar"] => waybar_status(),
        ["cancel"] => cancel(),
        ["retry"] => retry(false, false),
        ["retry", "--openai"] => retry(false, true),
        ["retry", "--skipped"] => retry(true, false),
        ["copy-status"] => copy_status(),
        ["secrets", "probe"] => secrets_probe(),
        ["secrets", "status"] => secrets_status(),
        ["secrets", "set-api-key"] => set_api_key(),
        ["secrets", "init-auth"] => init_auth(),
        ["settings", "show"] => settings_show(),
        ["settings", "model", model] => settings_model(model),
        ["settings", "language", language] => settings_language(language),
        ["settings", "target", "toggle"] => settings_target_toggle(),
        ["settings", "target", target] => settings_target(target),
        ["settings", "insert", "on"] => settings_insert(true),
        ["settings", "insert", "off"] => settings_insert(false),
        ["settings", "translation-model", model] => settings_translation_model(model),
        ["settings", "server", "off"] => settings_server_off(),
        ["settings", "server", address] => settings_server(address),
        ["record", "--daemon"] => worker(),
        _ => Err(tr!(
            "Unbekanntes Kommando. `opendictate help` zeigt die Befehle.",
            "Unknown command. `opendictate help` lists the commands."
        )),
    }
}

fn toggle() -> Result<(), String> {
    // Held until this call returns: a second `toggle` before the worker has
    // even bound its socket is refused instead of starting another worker.
    let _lock = lock_toggle()?.ok_or_else(starting)?;
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    match state::read(&state_path, &socket) {
        state::State::Idle => start_worker(),
        state::State::Recording => match ipc::send(&socket, ipc::STOP) {
            Ok(reply) if reply == ipc::PROCESSING => {
                println!(
                    "{}",
                    i18n::t(
                        "Aufnahme beendet. Wird zu Text …",
                        "Recording stopped. Turning it into text …"
                    )
                );
                Ok(())
            }
            Ok(_) => Err(tr!(
                "Aufnahme konnte nicht gestoppt werden.",
                "Recording could not be stopped."
            )),
            Err(_) => Err(tr!(
                "Aufnahmeprozess hat nicht geantwortet.",
                "Recording process did not respond."
            )),
        },
        state::State::Starting => Err(starting()),
        state::State::Processing | state::State::Delivering => Err(tr!(
            "OpenDictate verarbeitet bereits eine Aufnahme.",
            "OpenDictate is already processing a recording."
        )),
    }
}

/// Takes the lock shared by `toggle` and `retry`; `None` while another
/// command holds it.
fn lock_toggle() -> Result<Option<File>, String> {
    let file = OpenOptions::new()
        .create(true)
        .truncate(false)
        .write(true)
        .mode(0o600)
        .open(paths::toggle_lock_path().map_err(path_error)?)
        .map_err(path_error)?;
    // SAFETY: flock only reads the descriptor, which `file` keeps open.
    if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
        return match io::Error::last_os_error().kind() {
            io::ErrorKind::WouldBlock => Ok(None),
            _ => Err(tr!(
                "Aufnahme konnte nicht starten.",
                "Recording could not start."
            )),
        };
    }
    Ok(Some(file))
}

fn starting() -> String {
    tr!(
        "Die Aufnahme startet gerade. Versuch es gleich nochmal.",
        "The recording is starting. Try again in a moment."
    )
}

fn start_worker() -> Result<(), String> {
    let exe = std::env::current_exe()
        .map_err(|_| tr!("Programmdatei nicht gefunden.", "Program file not found."))?;
    let log = paths::worker_log_path().map_err(path_error)?;
    let log_file = open_operations_log(&log)
        .map_err(|_| tr!("Protokoll nicht schreibbar.", "Log is not writable."))?;
    let mut command = Command::new(exe);
    command
        .arg("record")
        .arg("--daemon")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(log_file)
        .env_remove("OPENAI_API_KEY")
        .env_remove("OPENDICTATE_API_KEY")
        .env(START_BY_ENV, start_by_millis().to_string());
    command.process_group(0);
    let mut child = command.spawn().map_err(|_| {
        tr!(
            "Aufnahmeprozess konnte nicht starten.",
            "Recording process could not start."
        )
    })?;
    // The worker gives up at the deadline passed above; waiting a second
    // longer means a recording never starts after this reported a failure.
    wait_for_recording(
        &mut child,
        &log,
        record::START_TIMEOUT + Duration::from_secs(1),
    )?;
    let started = i18n::t("Aufnahme läuft", "Recording");
    notify::status(started);
    println!("{started}");
    Ok(())
}

/// Passes the start deadline to the detached worker, as milliseconds since
/// the Unix epoch, so both processes measure it from the same moment.
const START_BY_ENV: &str = "OPENDICTATE_START_BY";

fn start_by_millis() -> u128 {
    (SystemTime::now() + record::START_TIMEOUT)
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.as_millis())
        .unwrap_or_default()
}

/// The deadline `toggle` passed in, or `START_TIMEOUT` from now when the
/// worker was started some other way.
fn start_deadline() -> SystemTime {
    std::env::var(START_BY_ENV)
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .map(|millis| UNIX_EPOCH + Duration::from_millis(millis))
        .unwrap_or_else(|| SystemTime::now() + record::START_TIMEOUT)
}

/// Waits until the detached worker reports a running recording. A worker that
/// exits first has written its reason to the log (its stderr).
fn wait_for_recording(child: &mut Child, log: &Path, timeout: Duration) -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    let cancel_path = paths::cancel_path().map_err(path_error)?;
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        let current = state::read(&state_path, &socket);
        // The worker clears the cancel request before it reports Starting, so
        // one seen from then on was made during this start, which then ends.
        if matches!(current, state::State::Starting | state::State::Recording)
            && cancel_path.is_file()
        {
            return Err(tr!("Aufnahme abgebrochen.", "Recording cancelled."));
        }
        if current == state::State::Recording {
            return Ok(());
        }
        // A second worker that lost the socket to a running one exits too;
        // only an exit that left no socket behind means the start failed.
        if matches!(child.try_wait(), Ok(Some(_))) && !socket.exists() {
            let log = log.display();
            return Err(tr!(
                "Aufnahme konnte nicht starten. Der Grund steht in {log}.",
                "Recording could not start. The reason is in {log}."
            ));
        }
        std::thread::sleep(Duration::from_millis(20));
    }
    Err(tr!(
        "Aufnahmeprozess hat nicht geantwortet.",
        "Recording process did not respond."
    ))
}

fn status() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    println!("{}", state::read(&state_path, &socket).as_str());
    if let Ok(path) = network_hint_path() {
        if fs::metadata(path)
            .ok()
            .and_then(|metadata| metadata.modified().ok())
            .and_then(|time| time.elapsed().ok())
            .is_some_and(|age| age < Duration::from_secs(24 * 60 * 60))
        {
            println!("{}", i18n::t("Letzte Server-Anfrage fehlgeschlagen: `opendictate retry --openai` sendet die gesicherte Aufnahme einmal an OpenAI.", "Last server request failed: `opendictate retry --openai` sends the kept recording to OpenAI once."));
        }
    }
    Ok(())
}

fn waybar_status() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    let state = state::read(&state_path, &socket);
    // A broken settings file must not blank the bar; show the state alone.
    let settings = paths::settings_path()
        .map_err(path_error)
        .and_then(|path| settings::Settings::load(&path))
        .unwrap_or_default();
    println!("{}", waybar::render(state, &settings));
    Ok(())
}

fn cancel() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    let cancel_path = paths::cancel_path().map_err(path_error)?;
    let mut current = state::read(&state_path, &socket);
    if current == state::State::Idle {
        return Err(tr!(
            "Keine laufende Aufnahme oder Verarbeitung.",
            "No recording or processing is running."
        ));
    }
    state::request_cancel(&cancel_path).map_err(path_error)?;
    // A start may switch to Recording right after the worker checked for a
    // cancel; then the recording has to be stopped like any other.
    let deadline = Instant::now() + record::START_TIMEOUT + Duration::from_secs(1);
    while current == state::State::Starting && Instant::now() < deadline {
        std::thread::sleep(Duration::from_millis(20));
        current = state::read(&state_path, &socket);
    }
    // The marker stays, so the worker ends the start once the microphone
    // answers; until then nothing has been cancelled yet.
    if current == state::State::Starting {
        return Err(tr!(
            "Das Mikrofon startet noch; die Aufnahme wird abgebrochen, sobald es antwortet.",
            "The microphone is still starting; the recording is cancelled once it responds."
        ));
    }
    // A worker that saw the cancel itself ends without answering; that is
    // the requested outcome, not a failure.
    if current == state::State::Recording
        && ipc::send(&socket, ipc::STOP).is_err()
        && state::read(&state_path, &socket) != state::State::Idle
    {
        return Err(tr!(
            "Aufnahmeprozess hat nicht geantwortet.",
            "Recording process did not respond."
        ));
    }
    println!("{}", cancel_requested());
    Ok(())
}

fn copy_status() -> Result<(), String> {
    clipboard::copy_text(i18n::t(CLIPBOARD_SPIKE_DE, CLIPBOARD_SPIKE_EN))?;
    let updated = i18n::t("Zwischenablage aktualisiert", "Clipboard updated");
    notify::status(updated);
    println!("{updated}");
    Ok(())
}

fn secrets_probe() -> Result<(), String> {
    keyring::probe()?;
    println!(
        "{}",
        i18n::t("Schlüsselbund erreichbar", "Keyring reachable")
    );
    Ok(())
}

fn secrets_status() -> Result<(), String> {
    let (api_key, recording_auth) = keyring::status()?;
    println!(
        "api-key={} recording-auth={}",
        present(api_key),
        present(recording_auth)
    );
    Ok(())
}

fn present(exists: bool) -> &'static str {
    if exists {
        "present"
    } else {
        "missing"
    }
}

fn set_api_key() -> Result<(), String> {
    if atty_stdin() {
        return Err(tr!(
            "Gib den API-Schlüssel per Pipe weiter, z. B. `printf %s \"$KEY\" | opendictate secrets set-api-key`.",
            "Pass the API key through a pipe, e.g. `printf %s \"$KEY\" | opendictate secrets set-api-key`."
        ));
    }
    let mut value = String::new();
    io::stdin().read_to_string(&mut value).map_err(|_| {
        tr!(
            "API-Schlüssel konnte nicht gelesen werden.",
            "API key could not be read."
        )
    })?;
    if value.ends_with('\n') {
        value.pop();
        if value.ends_with('\r') {
            value.pop();
        }
    }
    keyring::store_api_key(&value)?;
    println!("{}", i18n::t("API-Schlüssel gespeichert", "API key saved"));
    Ok(())
}

fn init_auth() -> Result<(), String> {
    keyring::ensure_recording_auth()?;
    println!(
        "{}",
        i18n::t(
            "Sicherungsschlüssel bereit",
            "Key for kept recordings ready"
        )
    );
    Ok(())
}

fn settings_show() -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let settings = settings::Settings::load(&path)?;
    let (server, source) = server::Server::resolve(settings.server.as_deref())?;
    let server = match source {
        server::Source::Default => "openai".to_string(),
        server::Source::Settings => server.base().to_string(),
        server::Source::Environment => format!("{} ({})", server.base(), server::BASE_URL_ENV),
    };
    println!(
        "model={} language={} target={} translation-model={} insert={} server={}",
        settings.model,
        settings.language.as_deref().unwrap_or("auto"),
        settings.target_language.as_deref().unwrap_or("off"),
        settings.translation_model,
        if settings.auto_insert { "on" } else { "off" },
        server
    );
    Ok(())
}

fn settings_model(model: &str) -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    let (server, _) = server::Server::resolve(settings.server.as_deref())?;
    settings::validate_model_for(model, &server)?;
    settings.model = model.to_string();
    settings.save(&path)?;
    println!("{}", i18n::t("Modell gespeichert", "Model saved"));
    Ok(())
}

fn settings_language(language: &str) -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    settings.language = if language == "auto" {
        None
    } else {
        settings::validate_language(language)?;
        Some(language.to_string())
    };
    settings.save(&path)?;
    println!("{}", i18n::t("Sprache gespeichert", "Language saved"));
    Ok(())
}

fn settings_target(target: &str) -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    settings.set_target(if target == "off" {
        None
    } else {
        settings::validate_language(target)?;
        Some(target.to_string())
    });
    settings.save(&path)?;
    println!(
        "{}",
        i18n::t("Zielsprache gespeichert", "Target language saved")
    );
    Ok(())
}

fn settings_target_toggle() -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    settings.toggle_target();
    settings.save(&path)?;
    let status = match settings.target_language.as_deref() {
        Some(target) => tr!("Übersetzung nach {target} an", "Translation to {target} on"),
        None => tr!("Übersetzung aus", "Translation off"),
    };
    notify::status(&status);
    println!("{status}");
    Ok(())
}

fn settings_insert(enabled: bool) -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    settings.auto_insert = enabled;
    settings.save(&path)?;
    println!(
        "{}",
        match enabled {
            true => i18n::t("Automatisches Einfügen an", "Auto-paste on"),
            false => i18n::t("Automatisches Einfügen aus", "Auto-paste off"),
        }
    );
    Ok(())
}

fn settings_translation_model(model: &str) -> Result<(), String> {
    settings::validate_translation_model(model)?;
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    settings.translation_model = model.to_string();
    settings.save(&path)?;
    println!(
        "{}",
        i18n::t("Übersetzungsmodell gespeichert", "Translation model saved")
    );
    Ok(())
}

fn shortcut_status() -> Result<(), String> {
    let binds = shortcut::active_binds();
    let current = shortcut::current(binds.as_deref());
    let config = match shortcut::detect(&shortcut::hypr_dir().map_err(path_error)?) {
        Some(target) => format!(
            "{} ({})",
            shortcut::display_path(&target.path),
            match target.style {
                shortcut::Style::OmarchyLua => "omarchy-lua",
                shortcut::Style::Lua => "lua",
                shortcut::Style::Classic => "classic",
            }
        ),
        None => "none".to_string(),
    };
    println!(
        "current={} config={config}",
        current.map(shortcut::Choice::id).unwrap_or("none")
    );
    for choice in shortcut::Choice::ALL {
        let availability = match shortcut::availability(choice, binds.as_deref()) {
            shortcut::Availability::Free => "free".to_string(),
            shortcut::Availability::OpenDictate => "opendictate".to_string(),
            shortcut::Availability::Taken(action) => format!("taken ({action})"),
            shortcut::Availability::Unknown => "unknown".to_string(),
        };
        println!("{}={availability}", choice.id());
    }
    if shortcut::has_other_opendictate_bind(binds.as_deref(), current) {
        println!("other-opendictate-bind=yes");
    }
    if shortcut::right_alt_suits() == Some(false) {
        println!(
            "{}",
            i18n::t(
                "Hinweis: Auf diesem Tastaturlayout ist die rechte Alt-Taste AltGr (für @, € usw.).",
                "Note: on this keyboard layout right Alt is AltGr (for @, € and so on)."
            )
        );
    }
    Ok(())
}

fn shortcut_set(id: &str) -> Result<(), String> {
    let choice = shortcut::Choice::from_id(id).ok_or_else(|| {
        tr!(
            "Unbekanntes Kürzel. Möglich: super-d, f9, right-alt.",
            "Unknown shortcut. Possible: super-d, f9, right-alt."
        )
    })?;
    let binds = shortcut::active_binds();
    if let shortcut::Availability::Taken(action) = shortcut::availability(choice, binds.as_deref())
    {
        return Err(tr!(
            "{} ist schon belegt ({action}). `opendictate setup` fragt, ob es trotzdem gelten soll.",
            "{} is already taken ({action}). `opendictate setup` asks whether to use it anyway.",
            choice.label()
        ));
    }
    if choice == shortcut::Choice::RightAlt && shortcut::right_alt_suits() == Some(false) {
        println!(
            "{}",
            i18n::t(
                "Achtung: Auf diesem Tastaturlayout ist die rechte Alt-Taste AltGr; Zeichen wie @ oder € gehen dann nicht mehr über sie.",
                "Careful: on this keyboard layout right Alt is AltGr; characters like @ or € no longer work through it."
            )
        );
    }
    setup::apply(choice, false).map(|_| ())
}

fn settings_server(address: &str) -> Result<(), String> {
    let server = server::Server::parse(address)?;
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    if !server.is_custom() {
        return settings_server_off();
    }
    settings.server = Some(server.base().to_string());
    settings.save(&path)?;
    println!(
        "{}",
        tr!(
            "Eigener Server gespeichert: {}",
            "Custom server saved: {}",
            server.base()
        )
    );
    if server.lacks_path() {
        println!(
            "{}",
            i18n::t(
                "Hinweis: Die meisten Server erwarten die Adresse mit /v1 am Ende.",
                "Note: most servers expect the address to end in /v1."
            )
        );
    }
    println!(
        "{}",
        if server.sends_api_key() {
            i18n::t(
                "Dein gespeicherter API-Schlüssel wird an diesen Server gesendet.",
                "Your stored API key is sent to this server.",
            )
        } else {
            i18n::t(
                "An Adressen auf diesem Rechner sendet OpenDictate keinen API-Schlüssel.",
                "OpenDictate sends no API key to addresses on this computer.",
            )
        }
    );
    println!(
        "{}",
        tr!(
            "Die Modellnamen deines Servers setzt du mit `opendictate settings model NAME`, für Übersetzungen mit `opendictate settings translation-model NAME` (jetzt: {}, {}).",
            "Set your server's model names with `opendictate settings model NAME`, for translations with `opendictate settings translation-model NAME` (now: {}, {}).",
            settings.model,
            settings.translation_model
        )
    );
    Ok(())
}

/// Back to OpenAI. A transcription model OpenAI does not offer is reset to
/// the default, so the next dictation does not fail.
fn settings_server_off() -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    settings.server = None;
    let (server, source) = server::Server::resolve(None)?;
    let reset_model = settings::validate_model_for(&settings.model, &server).is_err();
    if reset_model {
        settings.model = settings::DEFAULT_MODEL.to_string();
    }
    settings.save(&path)?;
    match source {
        server::Source::Environment => println!(
            "{}",
            tr!(
                "Gespeicherter Server entfernt; {} zeigt weiter auf {}.",
                "Stored server removed; {} still points to {}.",
                server::BASE_URL_ENV,
                server.base()
            )
        ),
        _ => println!(
            "{}",
            i18n::t(
                "Eigener Server aus; OpenDictate nutzt OpenAI.",
                "Custom server off; OpenDictate uses OpenAI."
            )
        ),
    }
    if reset_model {
        println!(
            "{}",
            tr!(
                "Modell für die Abschrift auf {} zurückgesetzt.",
                "Transcription model reset to {}.",
                settings::DEFAULT_MODEL
            )
        );
    }
    if settings.translation_model != settings::DEFAULT_TRANSLATION_MODEL {
        println!(
            "{}",
            tr!(
                "Übersetzungsmodell bleibt {}; `opendictate settings translation-model {}` stellt den Standard wieder her.",
                "Translation model stays {}; `opendictate settings translation-model {}` restores the default.",
                settings.translation_model,
                settings::DEFAULT_TRANSLATION_MODEL
            )
        );
    }
    Ok(())
}

/// The key for the server, or none for an address on this computer, which
/// works without a key and never receives one.
fn api_key_for(server: &server::Server) -> Result<Option<String>, String> {
    if server.sends_api_key() {
        keyring::api_key().map(Some)
    } else {
        Ok(None)
    }
}

/// Log suffix naming a custom server by host only, never path or key.
fn server_log(server: &server::Server) -> String {
    if server.is_custom() {
        format!(" server={}", server.log_host())
    } else {
        String::new()
    }
}

/// Returns the text to deliver: the transcript itself, or its translation
/// when a target language is set. Fails instead of falling back silently, so
/// the caller keeps the audio for retry.
fn deliverable_text(
    transcript: String,
    settings: &settings::Settings,
    server: &server::Server,
    api_key: Option<&str>,
    state_guard: &state::StateGuard,
) -> Result<String, String> {
    let Some(target) = settings.target_language.as_deref() else {
        return Ok(transcript);
    };
    log_ops(&format!(
        "translation-started target={target}{}",
        server_log(server)
    ));
    let translation = translate::Translator::new(server).translate(
        &transcript,
        target,
        &settings.translation_model,
        api_key,
    )?;
    ensure_not_cancelled(state_guard)?;
    if translation.is_empty() {
        return Err(tr!("Leere Übersetzung.", "Empty translation."));
    }
    Ok(translation)
}

/// Pastes into the window captured at recording start when allowed and
/// returns the status suffix. A skip keeps the text in the clipboard, except
/// when the clipboard no longer holds it: that is an undelivered transcript,
/// so the caller keeps the audio.
fn auto_insert(
    target: Option<&window::TargetWindow>,
    text: &str,
    settings: &settings::Settings,
    state_guard: &state::StateGuard,
) -> Result<Option<String>, String> {
    if !settings.auto_insert {
        return Ok(None);
    }
    let result = match target {
        _ if state_guard.is_cancelled() => Err(insert::Skip::Unavailable),
        Some(target) => insert::paste_into(target, text),
        None => Err(insert::Skip::Unavailable),
    };
    match result {
        Ok(()) => {
            log_ops("insert-sent");
            Ok(Some(tr!("eingefügt", "pasted")))
        }
        Err(skip) => {
            log_ops(&format!("insert-skipped reason={}", skip.log_reason()));
            if skip.loses_clipboard() {
                return Err(format!("{}.", skip.message()));
            }
            Ok(Some(tr!(
                "{} – der Text liegt in der Zwischenablage",
                "{} – the text is in the clipboard",
                skip.message()
            )))
        }
    }
}

fn delivered_status(settings: &settings::Settings, retry: bool) -> String {
    let copied = tr!(
        "{} in die Zwischenablage kopiert",
        "{} copied to the clipboard",
        delivered_subject(settings)
    );
    if retry {
        tr!("Nochmal gesendet. {copied}", "Sent again. {copied}")
    } else {
        copied
    }
}

fn delivered_subject(settings: &settings::Settings) -> String {
    match settings.target_language.as_deref() {
        Some(target) => tr!("Übersetzung ({target})", "Translation ({target})"),
        None => tr!("Text", "Text"),
    }
}

fn worker() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let listener = ipc::bind_socket(&socket).map_err(|error| {
        if error.kind() == io::ErrorKind::AddrInUse {
            tr!("Aufnahme läuft bereits.", "A recording is already running.")
        } else {
            tr!(
                "Aufnahmeprozess konnte nicht starten.",
                "Recording process could not start."
            )
        }
    })?;
    let _guard = SocketGuard {
        path: socket.clone(),
    };
    let deadline = start_deadline();
    let state_guard = state::StateGuard::begin(
        paths::state_path().map_err(path_error)?,
        paths::cancel_path().map_err(path_error)?,
        state::State::Starting,
    )
    .map_err(path_error)?;
    let target = window::active_window();
    if let Some(target) = &target {
        log_ops(&format!("window-captured class={}", target.class));
    }
    let path = paths::next_pending_path().map_err(path_error)?;
    restrict_file_parent(&path)?;
    // This process runs detached: `toggle` reports a started recording only
    // once the state says so, and a failed start is shown as a notification.
    let handle = record::start(&path).inspect_err(|error| notify::status(error))?;
    if SystemTime::now() > deadline {
        abort_start(handle, &path, "timeout");
        let error = tr!(
            "Das Mikrofon hat zu lange zum Starten gebraucht; die Aufnahme wurde abgebrochen.",
            "The microphone took too long to start; the recording was stopped."
        );
        notify::status(&error);
        return Err(error);
    }
    // A cancel written before this check ends the start here; a later one
    // finds Recording and stops it via the socket, keeping the audio.
    let published = ensure_not_cancelled(&state_guard)
        .and_then(|()| state_guard.set(state::State::Recording).map_err(path_error));
    if let Err(error) = published {
        let reason = if state_guard.is_cancelled() {
            "cancelled"
        } else {
            "state-failed"
        };
        abort_start(handle, &path, reason);
        return Err(error);
    }
    log_ops("recording-started");
    prune_stale_pending();
    let event = ipc::wait_for_stop(&listener, Instant::now() + record::MAX_RECORDING, &log_ops);
    state_guard
        .set(state::State::Processing)
        .map_err(path_error)?;
    if let Event::Stop(mut stream) = event {
        let _ = ipc::reply(&mut stream, ipc::PROCESSING);
    }
    let recording = handle
        .stop()
        .map_err(|error| keep_interrupted_recording(&path, error))?;
    restrict_file(&recording.path)?;
    log_ops(&format!(
        "recording-stopped milliseconds={}",
        recording.duration.as_millis()
    ));
    process_new_recording(&recording.path, target.as_ref(), &state_guard)
}

fn process_new_recording(
    path: &Path,
    target: Option<&window::TargetWindow>,
    state_guard: &state::StateGuard,
) -> Result<(), String> {
    clear_network_hint();
    let result = (|| {
        ensure_not_cancelled(state_guard)?;
        let prepared = match record::prepare_for_upload(path)? {
            record::Upload::Ready(prepared) => prepared,
            record::Upload::Skipped(message) => return Ok(Some(message)),
        };
        ensure_not_cancelled(state_guard)?;
        let settings = settings::Settings::load(&paths::settings_path().map_err(path_error)?)?;
        let (server, _) = server::Server::resolve(settings.server.as_deref())?;
        let api_key = api_key_for(&server)?;
        log_ops(&format!("transcription-started{}", server_log(&server)));
        let transcript = transcribe::Transcriber::new(&server)
            .transcribe(prepared.path(), api_key.as_deref(), &settings)
            .inspect_err(mark_network_failure)?;
        ensure_not_cancelled(state_guard)?;
        if transcript.is_empty() {
            return Err(tr!(
                "Kein Text erkannt. Die Aufnahme bleibt gesichert.",
                "No text came back. Your recording is kept."
            ));
        }
        let text = deliverable_text(
            transcript,
            &settings,
            &server,
            api_key.as_deref(),
            state_guard,
        )?;
        state_guard
            .set(state::State::Delivering)
            .map_err(path_error)?;
        clipboard::copy_text(&text)?;
        let insert_status = auto_insert(target, &text, &settings, state_guard)?;
        // `cancel` promises to keep the recording, also during delivery.
        ensure_not_cancelled(state_guard)?;
        if policy::can_delete_audio(&text, true) && fs::remove_file(path).is_err() {
            log_ops("pending-cleanup-failed");
        }
        let status = match insert_status {
            Some(insert_status) => {
                format!("{}: {insert_status}", delivered_subject(&settings))
            }
            None => delivered_status(&settings, false),
        };
        notify::status(&status);
        log_ops("transcription-copied");
        Ok(None)
    })();
    match result {
        Ok(None) => {
            prune_kept_recordings();
            Ok(())
        }
        Ok(Some(skipped)) => {
            // Kept like any other recording, but marked: plain `retry` passes
            // it over, and only `retry --skipped` sends it.
            let preservation = preserve_recording(path, true);
            log_ops(&format!(
                "recording-skipped preserved={}",
                preservation.is_ok()
            ));
            notify::status(&skipped);
            match preservation {
                Ok(()) => Err(tr!(
                    "{skipped} `opendictate retry --skipped` sendet sie trotzdem.",
                    "{skipped} `opendictate retry --skipped` sends it anyway."
                )),
                Err(preservation_error) => Err(tr!(
                    "{skipped} {preservation_error} Original blieb erhalten.",
                    "{skipped} {preservation_error} The original was kept."
                )),
            }
        }
        Err(error) => {
            log_ops("recording-kept");
            let preservation = preserve_recording(path, false);
            notify::status(&error);
            match preservation {
                Ok(()) => Err(tr!(
                    "{error} Die Aufnahme ist gesichert; `opendictate retry` sendet sie nochmal.",
                    "{error} The recording is kept; `opendictate retry` sends it again."
                )),
                Err(preservation_error) => Err(tr!(
                    "{error} {preservation_error} Original blieb erhalten.",
                    "{error} {preservation_error} The original was kept."
                )),
            }
        }
    }
}

fn network_hint_path() -> Result<std::path::PathBuf, String> {
    Ok(paths::state_dir()
        .map_err(path_error)?
        .join("custom-network-failure"))
}

fn clear_network_hint() {
    if let Ok(path) = network_hint_path() {
        let _ = fs::remove_file(path);
    }
}

fn mark_network_failure(error: &transcribe::Failure) {
    if !error.custom_network {
        return;
    }
    if let Ok(path) = network_hint_path() {
        if let Ok(mut file) = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW)
            .open(path)
        {
            let _ = file.write_all(b"custom-network-failure\n");
        }
    }
}

fn openai_retry_settings(saved: &settings::Settings) -> settings::Settings {
    let mut request = saved.clone();
    if settings::validate_model(&request.model).is_err() {
        request.model = settings::DEFAULT_MODEL.to_string();
    }
    if !request.translation_model.starts_with("gpt-") {
        request.translation_model = settings::DEFAULT_TRANSLATION_MODEL.to_string();
    }
    request
}

fn retry(skipped: bool, openai: bool) -> Result<(), String> {
    // Same lock as `toggle`, held until the socket and the Processing state
    // are in place: a retry cannot take the socket from a worker that
    // `toggle` is starting, and a later `toggle` sees Processing.
    let toggle_lock = lock_toggle()?.ok_or_else(|| {
        tr!(
            "OpenDictate ist gerade beschäftigt. Versuch es gleich nochmal.",
            "OpenDictate is busy right now. Try again in a moment."
        )
    })?;
    let socket = paths::socket_path().map_err(path_error)?;
    let _listener = ipc::bind_socket(&socket).map_err(|error| {
        if error.kind() == io::ErrorKind::AddrInUse {
            tr!(
                "OpenDictate ist bereits beschäftigt.",
                "OpenDictate is already busy."
            )
        } else {
            tr!(
                "OpenDictate konnte nicht nochmal senden.",
                "OpenDictate could not send again."
            )
        }
    })?;
    let _socket_guard = SocketGuard {
        path: socket.clone(),
    };
    let state_guard = state::StateGuard::begin(
        paths::state_path().map_err(path_error)?,
        paths::cancel_path().map_err(path_error)?,
        state::State::Processing,
    )
    .map_err(path_error)?;
    drop(toggle_lock);
    let auth = keyring::recording_auth()?;
    let recovery_dir = paths::recovery_dir().map_err(path_error)?;
    recovery::prune(&recovery_dir, &auth)?;
    let Some((entry, authenticated_bytes)) =
        recovery::newest_authenticated(&recovery_dir, &auth, skipped)?
    else {
        if !skipped && recovery::newest_authenticated(&recovery_dir, &auth, true)?.is_some() {
            return Err(tr!(
                "Gesichert sind nur zu kurze oder stille Aufnahmen. `opendictate retry --skipped` sendet die letzte davon trotzdem.",
                "Only recordings that were too short or silent are kept. `opendictate retry --skipped` sends the last one anyway."
            ));
        }
        return Err(tr!(
            "Keine gesicherte Aufnahme zum Nochmal-Senden.",
            "No kept recording to send again."
        ));
    };
    ensure_not_cancelled(&state_guard)?;
    let saved = settings::Settings::load(&paths::settings_path().map_err(path_error)?)?;
    let (settings, server) = if openai {
        (openai_retry_settings(&saved), server::Server::openai())
    } else {
        let (server, _) = server::Server::resolve(saved.server.as_deref())?;
        (saved, server)
    };
    clear_network_hint();
    let api_key = api_key_for(&server)?;
    log_ops(&format!("retry-started{}", server_log(&server)));
    let transcript = transcribe::Transcriber::new(&server)
        .transcribe_bytes(&authenticated_bytes, api_key.as_deref(), &settings)
        .inspect_err(mark_network_failure)?;
    ensure_not_cancelled(&state_guard)?;
    if transcript.is_empty() {
        return Err(tr!(
            "Kein Text erkannt. Die Aufnahme bleibt gesichert.",
            "No text came back. Your recording is kept."
        ));
    }
    let text = deliverable_text(
        transcript,
        &settings,
        &server,
        api_key.as_deref(),
        &state_guard,
    )?;
    state_guard
        .set(state::State::Delivering)
        .map_err(path_error)?;
    clipboard::copy_text(&text)?;
    recovery::delete(&entry)?;
    let status = delivered_status(&settings, true);
    notify::status(&status);
    log_ops("retry-copied");
    println!("{status}");
    Ok(())
}

/// Ends a start that is not used. A recording without audio and without a
/// capture error is removed;
/// one that already holds audio is secured for `retry` like any kept one,
/// and stays where it is if that fails.
fn abort_start(handle: record::RecordingHandle, path: &Path, reason: &str) {
    let Some(complete) = handle.abort() else {
        log_ops(&format!("recording-start-{reason} kept=false"));
        return;
    };
    let preserved = complete && preserve_recording(path, false).is_ok();
    log_ops(&format!(
        "recording-start-{reason} kept=true preserved={preserved}"
    ));
}

/// Reports a recording that ended with an error after it was stopped, such as
/// an unplugged microphone. The audio captured so far is secured for `retry`.
fn keep_interrupted_recording(path: &Path, error: record::StopError) -> String {
    let preservation = if error.complete {
        preserve_recording(path, false).map(|()| true)
    } else {
        Ok(false)
    };
    log_ops(&format!(
        "recording-stop-failed preserved={}",
        preservation == Ok(true)
    ));
    let message = error.message;
    let message = match preservation {
        Ok(true) => tr!(
            "{message} Die Aufnahme ist gesichert; `opendictate retry` sendet sie nochmal.",
            "{message} The recording is kept; `opendictate retry` sends it again."
        ),
        Ok(false) => tr!(
            "{message} Original blieb erhalten.",
            "{message} The original was kept."
        ),
        Err(preservation_error) => tr!(
            "{message} {preservation_error} Original blieb erhalten.",
            "{message} {preservation_error} The original was kept."
        ),
    };
    notify::status(&message);
    message
}

/// Removes kept recordings past the recovery limits after a dictation that
/// needed none, so they do not wait for the next failure. Best effort: the
/// dictation itself is done, and no key is created here.
fn prune_kept_recordings() {
    let Ok(recovery_dir) = paths::recovery_dir() else {
        return;
    };
    if !recovery::has_recordings(&recovery_dir) {
        return;
    }
    let pruned = keyring::recording_auth().and_then(|auth| recovery::prune(&recovery_dir, &auth));
    if pruned.is_err() {
        log_ops("recovery-prune-failed");
    }
}

/// Removes pending audio past the 24-hour limit; its secured copy could not
/// be made, so `retry` would never send it. Best effort.
fn prune_stale_pending() {
    let Ok(pending_dir) = paths::pending_dir() else {
        return;
    };
    let removed = recovery::prune_stale_pending(&pending_dir);
    if removed > 0 {
        log_ops(&format!("pending-pruned files={removed}"));
    }
}

fn preserve_recording(path: &Path, skipped: bool) -> Result<(), String> {
    if !path.exists() {
        return Ok(());
    }
    keyring::ensure_recording_auth()?;
    let auth = keyring::recording_auth()?;
    let recovery_dir = paths::recovery_dir().map_err(path_error)?;
    recovery::preserve(path, &recovery_dir, &auth, skipped)?;
    Ok(())
}

fn ensure_not_cancelled(state_guard: &state::StateGuard) -> Result<(), String> {
    if state_guard.is_cancelled() {
        Err(tr!("Verarbeitung abgebrochen.", "Processing cancelled."))
    } else {
        Ok(())
    }
}

fn restrict_file_parent(path: &Path) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(parent).map_err(path_error)?.permissions();
            perms.set_mode(0o700);
            fs::set_permissions(parent, perms).map_err(path_error)?;
        }
    }
    Ok(())
}

fn restrict_file(path: &Path) -> Result<(), String> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(path).map_err(path_error)?.permissions();
        perms.set_mode(0o600);
        fs::set_permissions(path, perms).map_err(path_error)?;
    }
    Ok(())
}

fn log_ops(event: &str) {
    let Ok(path) = paths::worker_log_path() else {
        return;
    };
    let Ok(mut file) = open_operations_log(&path) else {
        return;
    };
    let _ = writeln!(file, "{event}");
}

/// Above this size the operations log moves to `operations.log.1`, replacing
/// the previous one, so at most two bounded files exist.
const OPERATIONS_LOG_LIMIT: u64 = 1_024 * 1_024;

/// Opens the operations log for appending, owner-only (also when an older
/// version created it with a wider mode) and never through a symbolic link.
fn open_operations_log(path: &Path) -> io::Result<File> {
    use std::os::unix::fs::PermissionsExt;

    if fs::symlink_metadata(path).is_ok_and(|metadata| metadata.len() > OPERATIONS_LOG_LIMIT) {
        let mut rotated = path.as_os_str().to_owned();
        rotated.push(".1");
        fs::rename(path, rotated)?;
    }
    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path)?;
    file.set_permissions(fs::Permissions::from_mode(0o600))?;
    Ok(file)
}

fn path_error(error: io::Error) -> String {
    tr!(
        "OpenDictate-Verzeichnis nicht verfügbar: {error}",
        "OpenDictate folder unavailable: {error}"
    )
}

fn cancel_requested() -> &'static str {
    i18n::t(
        "Wird abgebrochen. Die Aufnahme bleibt gesichert.",
        "Cancelling. Your recording is kept.",
    )
}

fn atty_stdin() -> bool {
    io::stdin().is_terminal()
}

struct SocketGuard {
    path: std::path::PathBuf,
}

impl Drop for SocketGuard {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn one_off_openai_settings_do_not_change_the_saved_service() {
        let saved = crate::settings::Settings {
            model: "large-v3".to_string(),
            server: Some("http://127.0.0.1:8080/v1".to_string()),
            ..crate::settings::Settings::default()
        };
        let before = serde_json::to_vec(&saved).unwrap();
        let request = super::openai_retry_settings(&saved);
        assert_eq!(request.model, crate::settings::DEFAULT_MODEL);
        assert_eq!(serde_json::to_vec(&saved).unwrap(), before);
        assert!(crate::server::Server::openai().sends_api_key());
    }
    use super::*;

    #[test]
    fn unknown_command_is_an_error() {
        let error = run(vec!["nope".to_string()]).unwrap_err();
        assert!(error.contains("Unbekanntes Kommando"));
    }

    #[test]
    fn version_is_a_command() {
        assert!(run(vec!["version".to_string()]).is_ok());
        assert!(run(vec!["--version".to_string()]).is_ok());
    }

    #[test]
    fn operations_log_is_owner_only_and_rotates_once() {
        use std::os::unix::fs::PermissionsExt;

        let dir = test_support::unique_temp_dir("operations-log");
        let log = dir.join("operations.log");
        let rotated = dir.join("operations.log.1");
        fs::write(&log, b"old\n").unwrap();
        fs::set_permissions(&log, fs::Permissions::from_mode(0o644)).unwrap();
        writeln!(open_operations_log(&log).unwrap(), "event").unwrap();
        let mode = fs::metadata(&log).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o600);
        assert_eq!(fs::read_to_string(&log).unwrap(), "old\nevent\n");
        assert!(!rotated.exists());

        fs::write(&rotated, b"older").unwrap();
        fs::write(&log, vec![b'x'; OPERATIONS_LOG_LIMIT as usize + 1]).unwrap();
        writeln!(open_operations_log(&log).unwrap(), "fresh").unwrap();
        assert_eq!(fs::read_to_string(&log).unwrap(), "fresh\n");
        assert_eq!(
            fs::metadata(&rotated).unwrap().len(),
            OPERATIONS_LOG_LIMIT + 1
        );
        let mode = fs::metadata(&log).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o600);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn operations_log_is_not_opened_through_a_link() {
        let dir = test_support::unique_temp_dir("operations-log-link");
        let target = dir.join("elsewhere");
        fs::write(&target, b"").unwrap();
        std::os::unix::fs::symlink(&target, dir.join("operations.log")).unwrap();
        assert!(open_operations_log(&dir.join("operations.log")).is_err());
        let _ = fs::remove_dir_all(&dir);
    }
}
