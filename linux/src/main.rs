mod clipboard;
mod ipc;
mod keyring;
mod notify;
mod paths;
mod record;
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
opendictate — Linux-Spike (kein Produktumfang)

Befehle:
  toggle                 Aufnahme starten oder stoppen
  status                 idle oder recording
  copy-status            festen Statustext in die Zwischenablage
  secrets probe          Secret Service schreiben, lesen, löschen
  secrets status         ob API-Key und Recording-Auth existieren
  secrets set-api-key    API-Key von stdin speichern (kein Argument)
  secrets init-auth      Recording-Auth anlegen, falls fehlend
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
        ["copy-status"] => copy_status(),
        ["secrets", "probe"] => secrets_probe(),
        ["secrets", "status"] => secrets_status(),
        ["secrets", "set-api-key"] => set_api_key(),
        ["secrets", "init-auth"] => init_auth(),
        ["record", "--daemon"] => worker(),
        _ => Err("Unbekanntes Kommando. `opendictate help` zeigt die Befehle.".to_string()),
    }
}

fn toggle() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    if socket.exists() {
        match ipc::send(&socket, ipc::STOP) {
            Ok(reply) if reply == ipc::OK => {
                println!("Aufnahme gespeichert.");
                Ok(())
            }
            Ok(reply) if reply == ipc::NO_CLIPBOARD => {
                Err("Aufnahme gespeichert, Zwischenablage nicht verfügbar.".to_string())
            }
            Ok(_) => Err("Aufnahme konnte nicht gestoppt werden.".to_string()),
            Err(_) => Err("Aufnahmeprozess hat nicht geantwortet.".to_string()),
        }
    } else {
        start_worker()
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
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        if socket.exists() {
            return Ok(());
        }
        std::thread::sleep(Duration::from_millis(20));
    }
    Err("Aufnahmeprozess hat nicht geantwortet.".to_string())
}

fn status() -> Result<(), String> {
    let socket = paths::socket_path().map_err(path_error)?;
    if !socket.exists() {
        println!("idle");
        return Ok(());
    }
    match ipc::send(&socket, ipc::STATUS) {
        Ok(reply) if reply == ipc::RECORDING => {
            println!("recording");
            Ok(())
        }
        _ => {
            println!("idle");
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
    if let Some(target) = window::active_window() {
        log_ops(&format!("window-captured class={}", target.class));
    }
    let path = paths::next_recording_path().map_err(path_error)?;
    restrict_file_parent(&path)?;
    let handle = record::start(&path)?;
    log_ops("recording-started");
    let event = ipc::wait_for_stop(&listener, Instant::now() + record::MAX_RECORDING)
        .map_err(|_| "Aufnahme konnte nicht beendet werden.".to_string())?;
    let recording = handle.stop()?;
    restrict_file(&recording.path)?;
    let seconds = recording.duration.as_secs();
    let status_text = format!("OpenDictate: Aufnahme gespeichert ({seconds} s).");
    let clipboard_ok = match clipboard::copy_text(&status_text) {
        Ok(()) => true,
        Err(error) => {
            log_ops("clipboard-failed");
            notify::status(&error);
            false
        }
    };
    if clipboard_ok {
        notify::status("Aufnahme gespeichert");
        log_ops("recording-saved");
    }
    if let Event::Stop(mut stream) = event {
        let reply = if clipboard_ok {
            ipc::OK
        } else {
            ipc::NO_CLIPBOARD
        };
        let _ = ipc::reply(&mut stream, reply);
    }
    if clipboard_ok {
        Ok(())
    } else {
        Err("Aufnahme gespeichert, Zwischenablage nicht verfügbar.".to_string())
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
    fn usage_lists_toggle() {
        assert!(USAGE.contains("toggle"));
        assert!(USAGE.contains("secrets probe"));
    }

    #[test]
    fn unknown_command_is_an_error() {
        let error = run(vec!["nope".to_string()]).unwrap_err();
        assert!(error.contains("Unbekanntes Kommando"));
    }
}
