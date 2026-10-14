use std::process::{Command, Stdio};

use serde::Deserialize;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TargetWindow {
    pub address: String,
    pub class: String,
}

pub fn active_window() -> Option<TargetWindow> {
    let output = Command::new("hyprctl")
        .args(["activewindow", "-j"])
        .stdin(Stdio::null())
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    parse_active_window(&String::from_utf8_lossy(&output.stdout))
}

/// The two fields used from `hyprctl activewindow -j`. Other fields, such as
/// the window title, are skipped while parsing and never kept.
#[derive(Deserialize)]
struct ActiveWindow {
    address: Option<String>,
    class: Option<String>,
}

fn parse_active_window(json: &str) -> Option<TargetWindow> {
    let window: ActiveWindow = serde_json::from_str(json).ok()?;
    let address = window.address.filter(|address| !address.is_empty())?;
    Some(TargetWindow {
        address,
        class: window.class.unwrap_or_default(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_skips_title() {
        let json = r#"{
            "address": "0xabc",
            "class": "foot",
            "title": "secret user text"
        }"#;
        let window = parse_active_window(json).unwrap();
        assert_eq!(window.address, "0xabc");
        assert_eq!(window.class, "foot");
    }

    #[test]
    fn parse_reads_escapes_and_rejects_missing_windows() {
        let window = parse_active_window(r#"{"class":"a\"b","address":"0x1"}"#).unwrap();
        assert_eq!(window.class, "a\"b");
        assert_eq!(window.address, "0x1");
        assert_eq!(
            parse_active_window(r#"{"address":"0x2"}"#).unwrap().class,
            ""
        );
        assert!(parse_active_window("{}").is_none());
        assert!(parse_active_window(r#"{"address":""}"#).is_none());
        assert!(parse_active_window("Invalid").is_none());
    }
}
