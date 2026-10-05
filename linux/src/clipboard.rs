use std::io::{Read, Write};
use std::process::{Command, Stdio};

pub fn copy_text(text: &str) -> Result<(), String> {
    if std::env::var_os("WAYLAND_DISPLAY").is_none() {
        return Err("Zwischenablage nicht verfügbar (kein Wayland).".to_string());
    }
    let mut child = Command::new("wl-copy")
        .args(["--type", "text/plain"])
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|_| "Zwischenablage nicht verfügbar (wl-copy fehlt).".to_string())?;
    {
        let mut stdin = child
            .stdin
            .take()
            .ok_or_else(|| "Zwischenablage nicht verfügbar.".to_string())?;
        stdin
            .write_all(text.as_bytes())
            .map_err(|_| "Zwischenablage nicht verfügbar.".to_string())?;
    }
    let status = child
        .wait()
        .map_err(|_| "Zwischenablage nicht verfügbar.".to_string())?;
    if !status.success() {
        return Err("Zwischenablage nicht verfügbar.".to_string());
    }
    Ok(())
}

/// Reads the current plain-text clipboard, bounded, so auto-insert can check
/// that it still holds the delivered text.
pub fn read_text(limit: usize) -> Result<String, String> {
    let mut child = Command::new("wl-paste")
        .args(["--no-newline", "--type", "text/plain"])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|_| "Zwischenablage nicht lesbar (wl-paste fehlt).".to_string())?;
    let mut data = Vec::new();
    if let Some(stdout) = child.stdout.take() {
        let _ = stdout.take(limit as u64 + 1).read_to_end(&mut data);
    }
    if data.len() > limit {
        let _ = child.kill();
    }
    let status = child
        .wait()
        .map_err(|_| "Zwischenablage nicht lesbar.".to_string())?;
    if !status.success() || data.len() > limit {
        return Err("Zwischenablage nicht lesbar.".to_string());
    }
    String::from_utf8(data).map_err(|_| "Zwischenablage nicht lesbar.".to_string())
}

#[cfg(test)]
mod tests {
    #[test]
    fn copy_text_fails_without_wayland_display() {
        let previous = std::env::var_os("WAYLAND_DISPLAY");
        std::env::remove_var("WAYLAND_DISPLAY");
        let error = super::copy_text("x").unwrap_err();
        assert!(error.contains("Wayland"), "{error}");
        match previous {
            Some(value) => std::env::set_var("WAYLAND_DISPLAY", value),
            None => std::env::remove_var("WAYLAND_DISPLAY"),
        }
    }
}
