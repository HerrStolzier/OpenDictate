mod clipboard;
mod ipc;
mod keyring;
mod notify;
mod paths;
mod policy;
mod record;
mod recovery;
mod settings;
mod state;
mod transcribe;
mod window;

use std::fs::{self, OpenOptions};
use std::io::{self, IsTerminal, Read, Write};
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

use ipc::Event;

const CLIPBOARD_SPIKE: &str = "OpenDictate: Zwischenablage ok.";
const USAGE: &str = "\
opendictate — Linux Clipboard-MVP (kein Produktumfang)

Befehle:
  toggle                 Aufnahme starten oder stoppen
  status                 idle / recording / processing / delivering
  cancel                 Aufnahme oder Verarbeitung sicher abbrechen
  retry                  neueste authentifizierte Aufnahme erneut senden
  copy-status            festen Statustext in die Zwischenablage
  secrets probe          Secret Service schreiben, lesen, löschen
  secrets status         ob API-Key und Recording-Auth existieren
  secrets set-api-key    API-Key von stdin speichern (kein Argument)
  secrets init-auth      Recording-Auth anlegen, falls fehlend
  settings show          Modell und Sprache anzeigen
  settings model NAME    Upload-Modell setzen
  settings language CODE Sprache setzen; `auto` für Erkennung
  record --daemon        interner Aufnahmeprozess
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
            print!("{USAGE}");
            Ok(())
        }
        ["toggle"] => toggle(),
        ["status"] => status(),
        ["cancel"] => cancel(),
        ["retry"] => retry(),
        ["copy-status"] => copy_status(),
        ["secrets", "probe"] => secrets_probe(),
        ["secrets", "status"] => secrets_status(),
        ["secrets", "set-api-key"] => set_api_key(),
        ["secrets", "init-auth"] => init_auth(),
        ["settings", "show"] => settings_show(),
        ["settings", "model", model] => settings_model(model),
        ["settings", "language", language] => settings_language(language),
        ["record", "--daemon"] => worker(),
        _ => Err("Unbekanntes Kommando. `opendictate help` zeigt die Befehle.".to_string()),
    }
}

fn toggle() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    match state::read(&state_path, &socket) {
        state::State::Idle => start_worker(),
        state::State::Recording => match ipc::send(&socket, ipc::STOP) {
            Ok(reply) if reply == ipc::PROCESSING => {
                println!("Aufnahme beendet; Transkription läuft.");
                Ok(())
            }
            Ok(_) => Err("Aufnahme konnte nicht gestoppt werden.".to_string()),
            Err(_) => Err("Aufnahmeprozess hat nicht geantwortet.".to_string()),
        },
        state::State::Processing | state::State::Delivering => {
            Err("OpenDictate verarbeitet bereits eine Aufnahme.".to_string())
        }
    }
}

fn start_worker() -> Result<(), String> {
    let exe = std::env::current_exe().map_err(|_| "Binary nicht gefunden.".to_string())?;
    let log = paths::worker_log_path().map_err(path_error)?;
    let log_file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log)
        .map_err(|_| "Protokoll nicht schreibbar.".to_string())?;
    let mut command = Command::new(exe);
    command
        .arg("record")
        .arg("--daemon")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(log_file)
        .env_remove("OPENAI_API_KEY")
        .env_remove("OPENDICTATE_API_KEY");
    command.process_group(0);
    command
        .spawn()
        .map_err(|_| "Aufnahmeprozess konnte nicht starten.".to_string())?;
    wait_for_socket(Duration::from_secs(2))?;
    notify::status("Aufnahme läuft");
    println!("Aufnahme läuft");
    Ok(())
}

fn wait_for_socket(timeout: Duration) -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        if state::read(&state_path, &socket) == state::State::Recording {
            return Ok(());
        }
        std::thread::sleep(Duration::from_millis(20));
    }
    Err("Aufnahmeprozess hat nicht geantwortet.".to_string())
}

fn status() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    println!("{}", state::read(&state_path, &socket).as_str());
    Ok(())
}

fn cancel() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let state_path = paths::state_path().map_err(path_error)?;
    let cancel_path = paths::cancel_path().map_err(path_error)?;
    match state::read(&state_path, &socket) {
        state::State::Idle => Err("Keine laufende Aufnahme oder Verarbeitung.".to_string()),
        state::State::Recording => {
            state::request_cancel(&cancel_path).map_err(path_error)?;
            ipc::send(&socket, ipc::STOP)
                .map_err(|_| "Aufnahmeprozess hat nicht geantwortet.".to_string())?;
            println!("Abbruch angefordert; Aufnahme wird sicher behalten.");
            Ok(())
        }
        state::State::Processing | state::State::Delivering => {
            state::request_cancel(&cancel_path).map_err(path_error)?;
            println!("Abbruch angefordert; Aufnahme wird sicher behalten.");
            Ok(())
        }
    }
}

fn copy_status() -> Result<(), String> {
    clipboard::copy_text(CLIPBOARD_SPIKE)?;
    notify::status("Zwischenablage aktualisiert");
    println!("Zwischenablage aktualisiert");
    Ok(())
}

fn secrets_probe() -> Result<(), String> {
    keyring::probe()?;
    println!("Keyring erreichbar");
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
        return Err("API-Schlüssel nur über stdin, nicht als Argument.".to_string());
    }
    let mut value = String::new();
    io::stdin()
        .read_to_string(&mut value)
        .map_err(|_| "API-Schlüssel konnte nicht gelesen werden.".to_string())?;
    if value.ends_with('\n') {
        value.pop();
        if value.ends_with('\r') {
            value.pop();
        }
    }
    keyring::store_api_key(&value)?;
    println!("API-Schlüssel gespeichert");
    Ok(())
}

fn init_auth() -> Result<(), String> {
    keyring::ensure_recording_auth()?;
    println!("Recording-Auth bereit");
    Ok(())
}

fn settings_show() -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let settings = settings::Settings::load(&path)?;
    println!(
        "model={} language={}",
        settings.model,
        settings.language.as_deref().unwrap_or("auto")
    );
    Ok(())
}

fn settings_model(model: &str) -> Result<(), String> {
    settings::validate_model(model)?;
    let path = paths::settings_path().map_err(path_error)?;
    let mut settings = settings::Settings::load(&path)?;
    settings.model = model.to_string();
    settings.save(&path)?;
    println!("Modell gespeichert");
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
    println!("Sprache gespeichert");
    Ok(())
}

fn worker() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let listener = ipc::bind_socket(&socket).map_err(|error| {
        if error.kind() == io::ErrorKind::AddrInUse {
            "Aufnahme läuft bereits.".to_string()
        } else {
            "Aufnahmeprozess konnte nicht starten.".to_string()
        }
    })?;
    let _guard = SocketGuard {
        path: socket.clone(),
    };
    let state_guard = state::StateGuard::begin(
        paths::state_path().map_err(path_error)?,
        paths::cancel_path().map_err(path_error)?,
        state::State::Recording,
    )
    .map_err(path_error)?;
    if let Some(target) = window::active_window() {
        log_ops(&format!("window-captured class={}", target.class));
    }
    let path = paths::next_pending_path().map_err(path_error)?;
    restrict_file_parent(&path)?;
    let handle = record::start(&path)?;
    log_ops("recording-started");
    let event = ipc::wait_for_stop(&listener, Instant::now() + record::MAX_RECORDING)
        .map_err(|_| "Aufnahme konnte nicht beendet werden.".to_string())?;
    state_guard
        .set(state::State::Processing)
        .map_err(path_error)?;
    if let Event::Stop(mut stream) = event {
        let _ = ipc::reply(&mut stream, ipc::PROCESSING);
    }
    let recording = handle.stop().map_err(|error| {
        log_ops("recording-stop-failed");
        format!("{error} Originalaufnahme blieb erhalten.")
    })?;
    restrict_file(&recording.path)?;
    log_ops(&format!(
        "recording-stopped milliseconds={}",
        recording.duration.as_millis()
    ));
    process_new_recording(&recording.path, &state_guard)
}

fn process_new_recording(path: &Path, state_guard: &state::StateGuard) -> Result<(), String> {
    let result = (|| {
        ensure_not_cancelled(state_guard)?;
        let prepared = record::prepare_for_upload(path)?;
        ensure_not_cancelled(state_guard)?;
        let api_key = keyring::api_key()?;
        let settings = settings::Settings::load(&paths::settings_path().map_err(path_error)?)?;
        log_ops("transcription-started");
        let transcript =
            transcribe::Transcriber::new().transcribe(prepared.path(), &api_key, &settings)?;
        ensure_not_cancelled(state_guard)?;
        if transcript.is_empty() {
            return Err("Leere Transkription; Aufnahme wurde behalten.".to_string());
        }
        state_guard
            .set(state::State::Delivering)
            .map_err(path_error)?;
        clipboard::copy_text(&transcript)?;
        if policy::can_delete_audio(&transcript, true) && fs::remove_file(path).is_err() {
            log_ops("pending-cleanup-failed");
        }
        notify::status("Text in Zwischenablage kopiert");
        log_ops("transcription-copied");
        Ok(())
    })();
    match result {
        Ok(()) => Ok(()),
        Err(error) => {
            log_ops("recording-kept");
            let preservation = preserve_recording(path);
            notify::status(&error);
            match preservation {
                Ok(()) => Err(format!("{error} Aufnahme für Wiederholung behalten.")),
                Err(preservation_error) => Err(format!(
                    "{error} {preservation_error} Original blieb erhalten."
                )),
            }
        }
    }
}

fn retry() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    let _listener = ipc::bind_socket(&socket).map_err(|error| {
        if error.kind() == io::ErrorKind::AddrInUse {
            "OpenDictate ist bereits beschäftigt.".to_string()
        } else {
            "Wiederholung konnte nicht starten.".to_string()
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
    let auth = keyring::recording_auth()?;
    let recovery_dir = paths::recovery_dir().map_err(path_error)?;
    recovery::prune(&recovery_dir, &auth)?;
    let (entry, authenticated_bytes) = recovery::newest_authenticated(&recovery_dir, &auth)?
        .ok_or_else(|| "Keine authentifizierte Aufnahme für Wiederholung vorhanden.".to_string())?;
    ensure_not_cancelled(&state_guard)?;
    let api_key = keyring::api_key()?;
    let settings = settings::Settings::load(&paths::settings_path().map_err(path_error)?)?;
    log_ops("retry-started");
    let transcript = transcribe::Transcriber::new().transcribe_bytes(
        &authenticated_bytes,
        &api_key,
        &settings,
    )?;
    ensure_not_cancelled(&state_guard)?;
    if transcript.is_empty() {
        return Err("Leere Transkription; Aufnahme bleibt erhalten.".to_string());
    }
    state_guard
        .set(state::State::Delivering)
        .map_err(path_error)?;
    clipboard::copy_text(&transcript)?;
    recovery::delete(&entry)?;
    notify::status("Wiederholung in Zwischenablage kopiert");
    log_ops("retry-copied");
    println!("Wiederholung in Zwischenablage kopiert");
    Ok(())
}

fn preserve_recording(path: &Path) -> Result<(), String> {
    if !path.exists() {
        return Ok(());
    }
    keyring::ensure_recording_auth()?;
    let auth = keyring::recording_auth()?;
    let recovery_dir = paths::recovery_dir().map_err(path_error)?;
    recovery::preserve(path, &recovery_dir, &auth)?;
    Ok(())
}

fn ensure_not_cancelled(state_guard: &state::StateGuard) -> Result<(), String> {
    if state_guard.is_cancelled() {
        Err("Verarbeitung abgebrochen.".to_string())
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
    let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) else {
        return;
    };
    let _ = writeln!(file, "{event}");
}

fn path_error(_: io::Error) -> String {
    "Verzeichnis für den Spike nicht verfügbar.".to_string()
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
    use super::*;

    #[test]
    fn unknown_command_is_an_error() {
        let error = run(vec!["nope".to_string()]).unwrap_err();
        assert!(error.contains("Unbekanntes Kommando"));
    }
}
