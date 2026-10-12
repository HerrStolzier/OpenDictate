use std::process::{Command, Stdio};

use crate::clipboard;
use crate::i18n::t;
use crate::policy;
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
    "xterm",
    "urxvt",
    "st-256color",
    "com.gexperts.tilix",
];

/// Why a paste was not sent. Except for the two clipboard cases, the text is
/// known to be in the clipboard.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Skip {
    /// A shell runs every line it receives; multi-line text stays in the
    /// clipboard so the user pastes it on purpose.
    MultilineIntoTerminal,
    TargetNotFrontmost,
    ClipboardChanged,
    ClipboardUnreadable,
    Unavailable,
}

impl Skip {
    /// The transcript may no longer be in the clipboard, so the dictation
    /// counts as undelivered and the recording must be kept.
    pub fn loses_clipboard(self) -> bool {
        matches!(self, Self::ClipboardChanged | Self::ClipboardUnreadable)
    }

    pub fn log_reason(self) -> &'static str {
        match self {
            Self::MultilineIntoTerminal => "multiline-into-terminal",
            Self::TargetNotFrontmost => "target-not-frontmost",
            Self::ClipboardChanged => "clipboard-changed",
            Self::ClipboardUnreadable => "clipboard-unreadable",
            Self::Unavailable => "unavailable",
        }
    }

    pub fn message(self) -> &'static str {
        match self {
            Self::MultilineIntoTerminal => t(
                "Mehrzeiliger Text wird nicht in ein Terminal eingefügt",
                "Multi-line text is not pasted into a terminal",
            ),
            Self::TargetNotFrontmost => t(
                "Zielfenster ist nicht mehr vorne",
                "Target window is no longer in front",
            ),
            Self::ClipboardChanged => t(
                "Zwischenablage wurde vor dem Einfügen überschrieben",
                "Clipboard was overwritten before pasting",
            ),
            Self::ClipboardUnreadable => t(
                "Zwischenablage konnte vor dem Einfügen nicht geprüft werden",
                "Clipboard could not be checked before pasting",
            ),
            Self::Unavailable => t("Einfügen nicht möglich", "Pasting is not possible"),
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
    if is_terminal(&target.class) && policy::is_multiline(text) {
        return Err(Skip::MultilineIntoTerminal);
    }
    // Checked first, so every later skip can rely on the text still being
    // in the clipboard.
    let clipboard = clipboard::read_text(text.len() + 16).map_err(|_| Skip::ClipboardUnreadable)?;
    if clipboard != text {
        return Err(Skip::ClipboardChanged);
    }
    let frontmost = window::active_window().ok_or(Skip::Unavailable)?;
    if frontmost.address != target.address {
        return Err(Skip::TargetNotFrontmost);
    }
    // Hyprland with a Lua config only accepts Lua dispatchers; older or
    // hyprlang setups only the legacy form. A rejected form sends nothing, so
    // the other one is tried only after a clear rejection.
    match dispatch(&lua_dispatcher(target))? {
        Dispatch::Sent => Ok(()),
        Dispatch::Rejected => match dispatch_legacy(target)? {
            Dispatch::Sent => Ok(()),
            Dispatch::Rejected | Dispatch::Unclear => Err(Skip::Unavailable),
        },
        Dispatch::Unclear => Err(Skip::Unavailable),
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Dispatch {
    Sent,
    Rejected,
    Unclear,
}

fn dispatch(argument: &str) -> Result<Dispatch, Skip> {
    run_hyprctl(&["dispatch", argument])
}

fn dispatch_legacy(target: &TargetWindow) -> Result<Dispatch, Skip> {
    run_hyprctl(&["dispatch", "sendshortcut", &legacy_argument(target)])
}

fn run_hyprctl(args: &[&str]) -> Result<Dispatch, Skip> {
    let output = Command::new("hyprctl")
        .args(args)
        .stdin(Stdio::null())
        .output()
        .map_err(|_| Skip::Unavailable)?;
    let mut response = String::from_utf8_lossy(&output.stdout).into_owned();
    response.push_str(&String::from_utf8_lossy(&output.stderr));
    Ok(classify(output.status.success(), &response))
}

fn classify(success: bool, response: &str) -> Dispatch {
    let response = response.trim().to_ascii_lowercase();
    if success && (response == "ok" || response.is_empty()) {
        Dispatch::Sent
    } else if ["error", "invalid", "unknown", "not found", "syntax"]
        .iter()
        .any(|marker| response.contains(marker))
    {
        Dispatch::Rejected
    } else {
        Dispatch::Unclear
    }
}

fn lua_dispatcher(target: &TargetWindow) -> String {
    format!(
        "hl.dsp.send_shortcut({{ mods = \"{}\", key = \"V\", window = \"address:{}\" }})",
        paste_modifiers(&target.class),
        target.address
    )
}

fn legacy_argument(target: &TargetWindow) -> String {
    format!(
        "{}, V, address:{}",
        paste_modifiers(&target.class),
        target.address
    )
}

fn is_terminal(class: &str) -> bool {
    TERMINAL_CLASSES.contains(&class.to_ascii_lowercase().as_str())
}

fn paste_modifiers(class: &str) -> &'static str {
    if is_terminal(class) {
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
            legacy_argument(&target("Alacritty")),
            "CTRL SHIFT, V, address:0x5a1b2c"
        );
        assert_eq!(
            legacy_argument(&target("com.mitchellh.ghostty")),
            "CTRL SHIFT, V, address:0x5a1b2c"
        );
        assert_eq!(
            legacy_argument(&target("chromium")),
            "CTRL, V, address:0x5a1b2c"
        );
    }

    #[test]
    fn lua_dispatcher_targets_the_captured_address() {
        assert_eq!(
            lua_dispatcher(&target("com.mitchellh.ghostty")),
            r#"hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "V", window = "address:0x5a1b2c" })"#
        );
    }

    #[test]
    fn only_clear_rejections_allow_the_other_syntax() {
        assert_eq!(classify(true, "ok\n"), Dispatch::Sent);
        assert_eq!(classify(true, ""), Dispatch::Sent);
        assert_eq!(
            classify(true, "[string \"sendshortcut\"]:1: syntax error near 'V'"),
            Dispatch::Rejected
        );
        assert_eq!(classify(true, "Invalid dispatcher"), Dispatch::Rejected);
        assert_eq!(classify(false, "something else"), Dispatch::Unclear);
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
    fn multiline_text_stays_in_the_clipboard_for_terminals() {
        let skip = paste_into(&target("Alacritty"), "echo eins\ncurl böse | sh");
        assert_eq!(skip, Err(Skip::MultilineIntoTerminal));
        assert!(!Skip::MultilineIntoTerminal.loses_clipboard());
        assert_eq!(
            Skip::MultilineIntoTerminal.log_reason(),
            "multiline-into-terminal"
        );
    }
}
