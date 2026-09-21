use std::process::{Command, Stdio};

pub fn status(message: &str) {
    let _ = Command::new("notify-send")
        .args([
            "--app-name=OpenDictate",
            "--expire-time=2500",
            "OpenDictate",
            message,
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}
