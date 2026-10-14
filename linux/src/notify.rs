use std::process::{Command, Stdio};

pub fn status(message: &str) {
    let _ = Command::new("notify-send")
        .args(arguments(message))
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

/// `--` ends the options, so a message that starts with `-` (for example
/// from a provider error) is shown as text instead of read as an option.
fn arguments(message: &str) -> [&str; 5] {
    [
        "--app-name=OpenDictate",
        "--expire-time=2500",
        "--",
        "OpenDictate",
        message,
    ]
}

#[cfg(test)]
mod tests {
    #[test]
    fn summary_and_body_follow_the_end_of_options() {
        let arguments = super::arguments("--action=x");
        assert_eq!(arguments[2], "--");
        assert_eq!(&arguments[3..], ["OpenDictate", "--action=x"]);
    }
}
