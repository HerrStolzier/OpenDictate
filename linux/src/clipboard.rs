use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

/// Upper bound for `wl-paste`, which waits on whichever app owns the
/// clipboard and could otherwise block delivery forever.
const READ_TIMEOUT: Duration = Duration::from_secs(2);

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

/// Reads the current plain-text clipboard, bounded in size and time, so
/// auto-insert can check that it still holds the delivered text.
pub fn read_text(limit: usize) -> Result<String, String> {
    let mut command = Command::new("wl-paste");
    command.args(["--no-newline", "--type", "text/plain"]);
    read_output(command, limit, READ_TIMEOUT)
}

fn read_output(mut command: Command, limit: usize, timeout: Duration) -> Result<String, String> {
    let unreadable = || "Zwischenablage nicht lesbar.".to_string();
    let mut child = command
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|_| "Zwischenablage nicht lesbar (wl-paste fehlt).".to_string())?;
    let stdout = child.stdout.take().ok_or_else(unreadable)?;
    // The reader ends when wl-paste exits or is killed and closes the pipe.
    let reader = std::thread::spawn(move || {
        let mut data = Vec::new();
        let _ = stdout.take(limit as u64 + 1).read_to_end(&mut data);
        data
    });
    let deadline = Instant::now() + timeout;
    let status = loop {
        match child.try_wait() {
            Ok(Some(status)) => break Some(status),
            Ok(None) if Instant::now() < deadline && !reader.is_finished() => {
                std::thread::sleep(Duration::from_millis(10));
            }
            Ok(None) if reader.is_finished() => {
                // Output is complete or over the limit; give wl-paste a moment.
                break wait_until(&mut child, deadline);
            }
            _ => break None,
        }
    };
    let Some(status) = status else {
        let _ = child.kill();
        let _ = child.wait();
        // wl-paste forks a helper that can keep the pipe open after the kill,
        // so the reader is left to finish on its own instead of being joined.
        return Err(unreadable());
    };
    let data = reader.join().map_err(|_| unreadable())?;
    if status.success() && data.len() <= limit {
        String::from_utf8(data).map_err(|_| unreadable())
    } else {
        Err(unreadable())
    }
}

fn wait_until(
    child: &mut std::process::Child,
    deadline: Instant,
) -> Option<std::process::ExitStatus> {
    while Instant::now() < deadline {
        match child.try_wait() {
            Ok(Some(status)) => return Some(status),
            Ok(None) => std::thread::sleep(Duration::from_millis(10)),
            Err(_) => return None,
        }
    }
    None
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

    #[test]
    fn read_output_returns_bounded_text() {
        let mut command = std::process::Command::new("printf");
        command.arg("Hallo");
        let text = super::read_output(command, 16, std::time::Duration::from_secs(2));
        assert_eq!(text.unwrap(), "Hallo");
        let mut command = std::process::Command::new("printf");
        command.arg("zu lang");
        assert!(super::read_output(command, 3, std::time::Duration::from_secs(2)).is_err());
    }

    #[test]
    fn read_output_gives_up_on_a_hanging_owner() {
        let started = std::time::Instant::now();
        // Like wl-paste, the forked child keeps stdout open after a kill.
        let mut command = std::process::Command::new("sh");
        command.args(["-c", "sleep 10; true"]);
        let result = super::read_output(command, 16, std::time::Duration::from_millis(200));
        assert!(result.is_err());
        assert!(started.elapsed() < std::time::Duration::from_secs(5));
    }
}
