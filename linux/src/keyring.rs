use std::io::{Read, Write};
use std::process::{Command, Stdio};

const SERVICE: &str = "opendictate";

pub const API_KEY: &str = "api-key";
pub const RECORDING_AUTH: &str = "recording-auth";
const PROBE_KEY: &str = "spike-probe";

pub fn probe() -> Result<(), String> {
    require_secret_tool()?;
    let token = random_hex(32)?;
    store(PROBE_KEY, "OpenDictate spike probe", &token)?;
    let stored = lookup(PROBE_KEY);
    let _ = clear(PROBE_KEY);
    match stored {
        Ok(value) if value == token => Ok(()),
        Ok(_) => {
            Err("Keyring-Antwort stimmte nicht mit dem gespeicherten Wert überein.".to_string())
        }
        Err(error) => Err(error),
    }
}

pub fn status() -> Result<(bool, bool), String> {
    require_secret_tool()?;
    Ok((exists(API_KEY)?, exists(RECORDING_AUTH)?))
}

pub fn store_api_key(value: &str) -> Result<(), String> {
    require_secret_tool()?;
    if value.is_empty() {
        return Err("API-Schlüssel fehlt (stdin war leer).".to_string());
    }
    store(API_KEY, "OpenDictate API key", value)
}

pub fn ensure_recording_auth() -> Result<(), String> {
    require_secret_tool()?;
    if exists(RECORDING_AUTH)? {
        return Ok(());
    }
    let token = random_hex(32)?;
    store(
        RECORDING_AUTH,
        "OpenDictate recording authentication",
        &token,
    )
}

fn require_secret_tool() -> Result<(), String> {
    if which("secret-tool") {
        Ok(())
    } else {
        Err("Keyring nicht verfügbar (secret-tool fehlt).".to_string())
    }
}

fn store(key: &str, label: &str, value: &str) -> Result<(), String> {
    let mut child = Command::new("secret-tool")
        .args(["store", "--label", label, "service", SERVICE, "key", key])
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(secret_service_missing)?;
    {
        let mut stdin = child.stdin.take().ok_or_else(secret_service_unavailable)?;
        stdin
            .write_all(value.as_bytes())
            .map_err(|_| secret_service_unavailable())?;
    }
    let output = child
        .wait_with_output()
        .map_err(|_| secret_service_unavailable())?;
    if output.status.success() {
        Ok(())
    } else {
        Err(classify_secret_error(&output.stderr))
    }
}

fn lookup(key: &str) -> Result<String, String> {
    let output = Command::new("secret-tool")
        .args(["lookup", "service", SERVICE, "key", key])
        .stdin(Stdio::null())
        .output()
        .map_err(secret_service_missing)?;
    if output.status.success() {
        String::from_utf8(output.stdout)
            .map_err(|_| "Keyring-Antwort war nicht lesbar.".to_string())
    } else {
        Err(classify_secret_error(&output.stderr))
    }
}

fn exists(key: &str) -> Result<bool, String> {
    let output = Command::new("secret-tool")
        .args(["search", "service", SERVICE, "key", key])
        .stdin(Stdio::null())
        .output()
        .map_err(secret_service_missing)?;
    if output.status.success() {
        let text = String::from_utf8_lossy(&output.stdout);
        Ok(text.contains(key))
    } else {
        let message = String::from_utf8_lossy(&output.stderr);
        if message.to_ascii_lowercase().contains("cannot find") || output.stdout.is_empty() {
            Ok(false)
        } else if is_missing_service(&message) {
            Err(secret_service_unavailable())
        } else {
            Ok(false)
        }
    }
}

fn clear(key: &str) -> Result<(), String> {
    let output = Command::new("secret-tool")
        .args(["clear", "service", SERVICE, "key", key])
        .stdin(Stdio::null())
        .output()
        .map_err(secret_service_missing)?;
    if output.status.success() {
        Ok(())
    } else {
        Err(classify_secret_error(&output.stderr))
    }
}

fn random_hex(bytes: usize) -> Result<String, String> {
    let mut buf = vec![0u8; bytes];
    std::fs::File::open("/dev/urandom")
        .and_then(|mut file| file.read_exact(&mut buf))
        .map_err(|_| "Zufallsquelle nicht verfügbar.".to_string())?;
    Ok(buf.iter().map(|byte| format!("{byte:02x}")).collect())
}

fn which(name: &str) -> bool {
    std::env::var_os("PATH")
        .map(|paths| {
            std::env::split_paths(&paths).any(|dir| {
                let candidate = dir.join(name);
                candidate.is_file()
            })
        })
        .unwrap_or(false)
}

fn secret_service_missing(_: std::io::Error) -> String {
    secret_service_unavailable()
}

fn secret_service_unavailable() -> String {
    "Keyring nicht verfügbar.".to_string()
}

fn classify_secret_error(stderr: &[u8]) -> String {
    let message = String::from_utf8_lossy(stderr);
    if is_missing_service(&message) {
        secret_service_unavailable()
    } else {
        "Keyring nicht verfügbar.".to_string()
    }
}

fn is_missing_service(message: &str) -> bool {
    let lower = message.to_ascii_lowercase();
    lower.contains("org.freedesktop.secrets")
        || lower.contains("cannot autolaunch")
        || lower.contains("the name org.freedesktop.secrets")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classify_missing_bus_as_unavailable() {
        let error = classify_secret_error(
            b"The name org.freedesktop.secrets was not provided by any .service files",
        );
        assert_eq!(error, "Keyring nicht verfügbar.");
    }
}
