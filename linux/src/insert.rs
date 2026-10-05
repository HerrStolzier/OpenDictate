use std::process::{Command, Stdio};

use crate::clipboard;
use crate::window::{self, TargetWindow};

/// Window classes that paste with Ctrl+Shift+V instead of Ctrl+V.
const TERMINAL_CLASSES: &[&str] = &[
    "alacritty",
    "com.mitchellh.ghostty",
    "foot",
    "footclient",
    "kitty",
    "org.gnome.console",
    "org.gnome.terminal",
    "org.wezfurlong.wezterm",
    "konsole",
    "org.kde.konsole",
    "xterm-256color",
];

/// Why a paste was not sent. The text stays in the clipboard in every case.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Skip {
    TargetNotFrontmost,
    ClipboardChanged,
    Unavailable,
}

impl Skip {
    pub fn log_reason(self) -> &'static str {
        match self {
            Self::TargetNotFrontmost => "target-not-frontmost",
            Self::ClipboardChanged => "clipboard-changed",
            Self::Unavailable => "unavailable",
        }
    }

    pub fn message(self) -> &'static str {
        match self {
            Self::TargetNotFrontmost => "Zielfenster ist nicht mehr vorne",
            Self::ClipboardChanged => "Zwischenablage hat sich geändert",
            Self::Unavailable => "Einfügen nicht möglich",
        }
    }
}

/// Sends the paste shortcut to the window captured at recording start, but
/// only while it is still frontmost and the clipboard still holds `text`.
/// The paste itself stays unconfirmed: Hyprland only reports that it sent
/// the keys.
pub fn paste_into(target: &TargetWindow, text: &str) -> Result<(), Skip> {
    if !valid_address(&target.address) {
        return Err(Skip::Unavailable);
    }
    let frontmost = window::active_window().ok_or(Skip::Unavailable)?;
    if frontmost.address != target.address {
        return Err(Skip::TargetNotFrontmost);
    }
    let clipboard = clipboard::read_text(text.len() + 16).map_err(|_| Skip::ClipboardChanged)?;
    if !same_text(&clipboard, text) {
        return Err(Skip::ClipboardChanged);
    }
    let output = Command::new("hyprctl")
        .args(["dispatch", "sendshortcut", &shortcut_argument(target)])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .map_err(|_| Skip::Unavailable)?;
    if output.status.success() && String::from_utf8_lossy(&output.stdout).trim() == "ok" {
        Ok(())
    } else {
        Err(Skip::Unavailable)
    }
}

fn shortcut_argument(target: &TargetWindow) -> String {
    format!(
        "{}, V, address:{}",
        paste_modifiers(&target.class),
        target.address
    )
}

fn paste_modifiers(class: &str) -> &'static str {
    let class = class.to_ascii_lowercase();
    if TERMINAL_CLASSES.contains(&class.as_str()) {
        "CTRL SHIFT"
    } else {
        "CTRL"
    }
}

fn valid_address(address: &str) -> bool {
    address.strip_prefix("0x").is_some_and(|hex| {
        !hex.is_empty() && hex.len() <= 16 && hex.chars().all(|c| c.is_ascii_hexdigit())
    })
}

fn same_text(clipboard: &str, text: &str) -> bool {
    clipboard == text || clipboard.trim_end_matches('\n') == text.trim_end_matches('\n')
}

#[cfg(test)]
mod tests {
    use super::*;

    fn target(class: &str) -> TargetWindow {
        TargetWindow {
            address: "0x5a1b2c".to_string(),
            class: class.to_string(),
        }
    }

    #[test]
    fn terminals_paste_with_shift() {
        assert_eq!(
            shortcut_argument(&target("Alacritty")),
            "CTRL SHIFT, V, address:0x5a1b2c"
        );
        assert_eq!(
            shortcut_argument(&target("com.mitchellh.ghostty")),
            "CTRL SHIFT, V, address:0x5a1b2c"
        );
        assert_eq!(
            shortcut_argument(&target("chromium")),
            "CTRL, V, address:0x5a1b2c"
        );
    }

    #[test]
    fn only_hex_window_addresses_are_accepted() {
        assert!(valid_address("0x5a1b2c"));
        assert!(!valid_address("0x"));
        assert!(!valid_address("5a1b2c"));
        assert!(!valid_address("0x5a, exec, rm"));
    }

    #[test]
    fn invalid_target_is_never_pasted() {
        let mut window = target("foot");
        window.address = "0xzz".to_string();
        assert_eq!(paste_into(&window, "Hallo"), Err(Skip::Unavailable));
    }

    #[test]
    fn clipboard_comparison_ignores_only_trailing_newlines() {
        assert!(same_text("Hallo\n", "Hallo"));
        assert!(!same_text("Hallo Welt", "Hallo"));
    }
}
