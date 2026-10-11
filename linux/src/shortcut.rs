//! The start shortcut: the suggested keys, whether Hyprland already uses
//! them, and the bind line in the user's Hyprland config.

use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

use serde::Deserialize;

use crate::i18n::t;

const COMMAND: &str = "opendictate toggle";
const MARKER: &str = "OpenDictate: start and stop dictation (opendictate setup)";

/// Hyprland's modifier bits in `hyprctl binds -j`.
const MOD_ALT: u64 = 8;
const MOD_SUPER: u64 = 64;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Choice {
    SuperD,
    F9,
    RightAlt,
}

impl Choice {
    pub const ALL: [Choice; 3] = [Choice::SuperD, Choice::F9, Choice::RightAlt];

    pub fn id(self) -> &'static str {
        match self {
            Choice::SuperD => "super-d",
            Choice::F9 => "f9",
            Choice::RightAlt => "right-alt",
        }
    }

    pub fn from_id(id: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|choice| choice.id() == id)
    }

    pub fn label(self) -> &'static str {
        match self {
            Choice::SuperD => "Super+D",
            Choice::F9 => "F9",
            Choice::RightAlt => t("Rechte Alt-Taste allein", "Right Alt key alone"),
        }
    }

    fn matches(self, modmask: u64, key: &str) -> bool {
        match self {
            Choice::SuperD => modmask == MOD_SUPER && key.eq_ignore_ascii_case("d"),
            Choice::F9 => modmask == 0 && key.eq_ignore_ascii_case("f9"),
            Choice::RightAlt => {
                (modmask == 0 || modmask == MOD_ALT) && key.eq_ignore_ascii_case("alt_r")
            }
        }
    }

    /// The line for the given config style. A modifier key alone fires on
    /// release in the classic syntax, so Alt+Tab and the like keep working.
    pub fn line(self, style: Style) -> String {
        let lua_keys = match self {
            Choice::SuperD => "SUPER + D",
            Choice::F9 => "F9",
            Choice::RightAlt => "Alt_R",
        };
        match style {
            Style::OmarchyLua => format!("o.bind(\"{lua_keys}\", \"OpenDictate\", \"{COMMAND}\")"),
            Style::Lua => format!("hl.bind(\"{lua_keys}\", hl.dsp.exec_cmd(\"{COMMAND}\"))"),
            Style::Classic => match self {
                Choice::SuperD => format!("bind = SUPER, D, exec, {COMMAND}"),
                Choice::F9 => format!("bind = , F9, exec, {COMMAND}"),
                Choice::RightAlt => format!("bindr = ALT, Alt_R, exec, {COMMAND}"),
            },
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Style {
    /// Omarchy 4: `o.bind(keys, description, command)` in bindings.lua.
    OmarchyLua,
    /// Plain Hyprland Lua config; its layout varies too much to edit.
    Lua,
    /// hyprlang: `bind = MODS, key, exec, command`.
    Classic,
}

impl Style {
    fn comment(self) -> &'static str {
        match self {
            Style::OmarchyLua | Style::Lua => "--",
            Style::Classic => "#",
        }
    }
}

/// The config file OpenDictate would write the bind into.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Target {
    pub path: PathBuf,
    pub style: Style,
}

impl Target {
    /// Plain Lua configs are only shown the line, never edited.
    pub fn writable(&self) -> bool {
        self.style != Style::Lua
    }
}

pub fn hypr_dir() -> PathBuf {
    std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))
        .unwrap_or_else(|| PathBuf::from(".config"))
        .join("hypr")
}

/// A path for messages, with the home folder shortened to `~`.
pub fn display_path(path: &Path) -> String {
    let home = std::env::var_os("HOME").map(PathBuf::from);
    match home
        .as_deref()
        .and_then(|home| path.strip_prefix(home).ok())
    {
        Some(rest) if !rest.as_os_str().is_empty() => format!("~/{}", rest.display()),
        _ => path.display().to_string(),
    }
}

/// Finds where binds live: Omarchy 4's bindings.lua, a plain Lua config,
/// Omarchy 3's bindings.conf, or hyprland.conf.
pub fn detect(hypr_dir: &Path) -> Option<Target> {
    let bindings_lua = hypr_dir.join("bindings.lua");
    if fs::read_to_string(&bindings_lua).is_ok_and(|text| text.contains("o.bind(")) {
        return Some(Target {
            path: bindings_lua,
            style: Style::OmarchyLua,
        });
    }
    let hyprland_lua = hypr_dir.join("hyprland.lua");
    if hyprland_lua.is_file() {
        return Some(Target {
            path: hyprland_lua,
            style: Style::Lua,
        });
    }
    ["bindings.conf", "hyprland.conf"]
        .into_iter()
        .map(|name| hypr_dir.join(name))
        .find(|path| path.is_file())
        .map(|path| Target {
            path,
            style: Style::Classic,
        })
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Bind {
    modmask: u64,
    key: String,
    /// What the bind does, for "taken by …".
    action: String,
    opendictate: bool,
}

/// The binds Hyprland has loaded right now; `None` without a running
/// Hyprland.
pub fn active_binds() -> Option<Vec<Bind>> {
    let output = Command::new("hyprctl")
        .args(["binds", "-j"])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    parse_binds(&output.stdout)
}

fn parse_binds(json: &[u8]) -> Option<Vec<Bind>> {
    #[derive(Deserialize)]
    struct Raw {
        #[serde(default)]
        modmask: u64,
        #[serde(default)]
        key: String,
        #[serde(default)]
        description: String,
        #[serde(default)]
        dispatcher: String,
        #[serde(default)]
        arg: String,
    }
    let raw: Vec<Raw> = serde_json::from_slice(json).ok()?;
    Some(
        raw.into_iter()
            .map(|bind| {
                let opendictate = [&bind.description, &bind.arg]
                    .iter()
                    .any(|text| text.to_ascii_lowercase().contains("opendictate"));
                let action = if !bind.description.is_empty() {
                    bind.description
                } else {
                    format!("{} {}", bind.dispatcher, bind.arg)
                        .trim()
                        .to_string()
                };
                Bind {
                    modmask: bind.modmask,
                    key: bind.key,
                    action: shorten(&action),
                    opendictate,
                }
            })
            .collect(),
    )
}

fn shorten(text: &str) -> String {
    const MAX: usize = 40;
    if text.chars().count() <= MAX {
        text.to_string()
    } else {
        format!("{}…", text.chars().take(MAX - 1).collect::<String>())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Availability {
    Free,
    OpenDictate,
    Taken(String),
    /// Hyprland is not running, so nothing could be checked.
    Unknown,
}

pub fn availability(choice: Choice, binds: Option<&[Bind]>) -> Availability {
    let Some(binds) = binds else {
        return Availability::Unknown;
    };
    let matching: Vec<&Bind> = binds
        .iter()
        .filter(|bind| choice.matches(bind.modmask, &bind.key))
        .collect();
    if matching.iter().any(|bind| bind.opendictate) {
        Availability::OpenDictate
    } else if let Some(bind) = matching.first() {
        Availability::Taken(bind.action.clone())
    } else {
        Availability::Free
    }
}

/// The choice an existing OpenDictate bind uses, if it is one of ours.
pub fn current(binds: Option<&[Bind]>) -> Option<Choice> {
    Choice::ALL
        .into_iter()
        .find(|choice| availability(*choice, binds) == Availability::OpenDictate)
}

/// Whether an OpenDictate bind exists on a key other than `chosen`, e.g.
/// one left in another config file.
pub fn has_other_opendictate_bind(binds: Option<&[Bind]>, chosen: Option<Choice>) -> bool {
    binds.is_some_and(|binds| {
        binds.iter().any(|bind| {
            bind.opendictate
                && !chosen.is_some_and(|choice| choice.matches(bind.modmask, &bind.key))
        })
    })
}

/// Right Alt alone suits a plain US layout. On most other layouts it is
/// AltGr, which types characters like @ or €. `None` when unknown.
pub fn right_alt_suits() -> Option<bool> {
    let output = Command::new("hyprctl")
        .args(["devices", "-j"])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    layout_suits_right_alt(&output.stdout)
}

fn layout_suits_right_alt(json: &[u8]) -> Option<bool> {
    #[derive(Deserialize)]
    struct Devices {
        #[serde(default)]
        keyboards: Vec<Keyboard>,
    }
    #[derive(Deserialize)]
    struct Keyboard {
        #[serde(default)]
        layout: String,
        #[serde(default)]
        variant: String,
        #[serde(default)]
        main: bool,
    }
    let devices: Devices = serde_json::from_slice(json).ok()?;
    let keyboard = devices
        .keyboards
        .iter()
        .find(|keyboard| keyboard.main)
        .or_else(|| devices.keyboards.first())?;
    let layout = keyboard.layout.split(',').next().unwrap_or("").trim();
    let variant = keyboard.variant.split(',').next().unwrap_or("").trim();
    Some(layout == "us" && variant.is_empty())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Installed {
    pub backup: PathBuf,
    pub replaced: usize,
}

/// Writes the bind into the target file: removes earlier OpenDictate binds
/// in that file, appends the new line and keeps a backup next to it. The
/// new text replaces the file in one step, so a failed write leaves the
/// working config untouched; a symlinked dotfile stays a symlink.
pub fn install(choice: Choice, target: &Target) -> Result<Installed, String> {
    if !target.writable() {
        return Err(t(
            "Diese Hyprland-Konfiguration kann OpenDictate nicht selbst ändern.",
            "OpenDictate cannot edit this Hyprland config itself.",
        )
        .to_string());
    }
    let original = fs::read_to_string(&target.path).map_err(|_| unreadable(&target.path))?;
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or_default();
    let file_name = target
        .path
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default();
    let backup = target
        .path
        .with_file_name(format!("{file_name}.opendictate-backup-{stamp}"));
    fs::copy(&target.path, &backup).map_err(|_| {
        crate::tr!(
            "Sicherung von {} nicht möglich; nichts geändert.",
            "Could not back up {}; nothing changed.",
            display_path(&target.path)
        )
    })?;
    let (updated, replaced) = with_bind(&original, choice, target.style);
    if replace_contents(&target.path, &updated).is_err() {
        let _ = fs::remove_file(&backup);
        return Err(crate::tr!(
            "{} nicht schreibbar; nichts geändert.",
            "{} is not writable; nothing changed.",
            display_path(&target.path)
        ));
    }
    Ok(Installed { backup, replaced })
}

/// Puts the config from before `install` back, for a bind Hyprland did not
/// take, and drops the backup, which then equals the file.
pub fn restore(target: &Target, installed: &Installed) -> Result<(), String> {
    let failed = || {
        crate::tr!(
            "{} ließ sich nicht zurücksetzen; die Sicherung liegt unter {}.",
            "Could not restore {}; the backup is at {}.",
            display_path(&target.path),
            display_path(&installed.backup)
        )
    };
    let original = fs::read(&installed.backup).map_err(|_| failed())?;
    replace_contents(&target.path, &original).map_err(|_| failed())?;
    let _ = fs::remove_file(&installed.backup);
    Ok(())
}

/// Asks Hyprland to read its config again; false without a running Hyprland.
pub fn reload() -> bool {
    Command::new("hyprctl")
        .arg("reload")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|status| status.success())
}

/// Writes a sibling file and renames it over the real file (behind a
/// symlink), so readers see either the old or the new text, never a
/// truncated one.
fn replace_contents(path: &Path, contents: impl AsRef<[u8]>) -> io::Result<()> {
    let real = fs::canonicalize(path)?;
    let permissions = fs::metadata(&real)?.permissions();
    let name = real
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default();
    let temporary = real.with_file_name(format!(".{name}.opendictate-{}", std::process::id()));
    let written = (|| {
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temporary)?;
        file.write_all(contents.as_ref())?;
        file.set_permissions(permissions)?;
        file.sync_all()?;
        fs::rename(&temporary, &real)
    })();
    if written.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    written
}

fn unreadable(path: &Path) -> String {
    crate::tr!("{} nicht lesbar.", "{} is unreadable.", display_path(path))
}

/// The config text with exactly one OpenDictate bind, appended at the end;
/// in a Lua file that ends with `return …`, right before that statement.
fn with_bind(original: &str, choice: Choice, style: Style) -> (String, usize) {
    let mut replaced = 0;
    let mut kept: Vec<&str> = Vec::new();
    for line in original.lines() {
        if line.contains(MARKER) {
            continue;
        }
        if is_opendictate_bind(line) {
            replaced += 1;
            continue;
        }
        kept.push(line);
    }
    while kept.last().is_some_and(|line| line.trim().is_empty()) {
        kept.pop();
    }
    let tail_start = match style {
        Style::OmarchyLua | Style::Lua => kept
            .iter()
            .rposition(|line| {
                let trimmed = line.trim_start();
                !trimmed.is_empty() && !trimmed.starts_with("--")
            })
            .filter(|index| kept[*index].trim_start().starts_with("return")),
        Style::Classic => None,
    }
    .unwrap_or(kept.len());
    let (head, tail) = kept.split_at(tail_start);
    let mut text = head.join("\n");
    while text.ends_with('\n') {
        text.pop();
    }
    if !text.is_empty() {
        text.push_str("\n\n");
    }
    text.push_str(&format!(
        "{} {MARKER}\n{}\n",
        style.comment(),
        choice.line(style)
    ));
    if !tail.is_empty() {
        text.push('\n');
        text.push_str(&tail.join("\n"));
        text.push('\n');
    }
    (text, replaced)
}

/// An active bind line that runs OpenDictate; comments stay untouched.
fn is_opendictate_bind(line: &str) -> bool {
    let trimmed = line.trim_start();
    let is_bind = trimmed.starts_with("o.bind(")
        || trimmed.starts_with("hl.bind(")
        || trimmed.starts_with("bind");
    is_bind && trimmed.contains(COMMAND)
}

#[cfg(test)]
mod tests {
    use super::*;

    const BINDS: &str = r#"[
        {"locked":false,"modmask":64,"submap":"","key":"D","keycode":0,"description":"OpenDictate","dispatcher":"exec","arg":"opendictate toggle"},
        {"modmask":64,"key":"RETURN","description":"Terminal","dispatcher":"exec","arg":"uwsm-app -- xdg-terminal-exec"},
        {"modmask":0,"key":"F9","description":"","dispatcher":"exec","arg":"some-very-long-command --with --many --arguments --that --goes --on"}
    ]"#;

    fn binds() -> Vec<Bind> {
        parse_binds(BINDS.as_bytes()).unwrap()
    }

    #[test]
    fn availability_tells_free_taken_and_ours_apart() {
        let binds = binds();
        assert_eq!(
            availability(Choice::SuperD, Some(&binds)),
            Availability::OpenDictate
        );
        match availability(Choice::F9, Some(&binds)) {
            Availability::Taken(action) => {
                assert!(action.starts_with("exec some-very-long"));
                assert!(action.chars().count() <= 40);
            }
            other => panic!("{other:?}"),
        }
        assert_eq!(
            availability(Choice::RightAlt, Some(&binds)),
            Availability::Free
        );
        assert_eq!(availability(Choice::F9, None), Availability::Unknown);
        assert_eq!(current(Some(&binds)), Some(Choice::SuperD));
        assert!(!has_other_opendictate_bind(
            Some(&binds),
            Some(Choice::SuperD)
        ));
        assert!(has_other_opendictate_bind(Some(&binds), Some(Choice::F9)));
    }

    #[test]
    fn an_opendictate_bind_on_another_key_is_noticed() {
        let binds = parse_binds(
            br#"[{"modmask":72,"key":"D","description":"","dispatcher":"exec","arg":"opendictate toggle"}]"#,
        )
        .unwrap();
        assert_eq!(current(Some(&binds)), None);
        assert!(has_other_opendictate_bind(Some(&binds), None));
    }

    #[test]
    fn lines_follow_the_config_style() {
        assert_eq!(
            Choice::SuperD.line(Style::OmarchyLua),
            r#"o.bind("SUPER + D", "OpenDictate", "opendictate toggle")"#
        );
        assert_eq!(
            Choice::F9.line(Style::Classic),
            "bind = , F9, exec, opendictate toggle"
        );
        assert_eq!(
            Choice::RightAlt.line(Style::Classic),
            "bindr = ALT, Alt_R, exec, opendictate toggle"
        );
        assert_eq!(
            Choice::RightAlt.line(Style::Lua),
            r#"hl.bind("Alt_R", hl.dsp.exec_cmd("opendictate toggle"))"#
        );
        for choice in Choice::ALL {
            assert_eq!(Choice::from_id(choice.id()), Some(choice));
        }
    }

    #[test]
    fn right_alt_only_suits_a_plain_us_layout() {
        let devices = |layout: &str, variant: &str| {
            format!(
                r#"{{"mice":[],"keyboards":[{{"name":"other","layout":"de","variant":"","main":false}},{{"name":"main","layout":"{layout}","variant":"{variant}","main":true}}]}}"#
            )
        };
        assert_eq!(
            layout_suits_right_alt(devices("us", "").as_bytes()),
            Some(true)
        );
        assert_eq!(
            layout_suits_right_alt(devices("us,de", ",").as_bytes()),
            Some(true)
        );
        assert_eq!(
            layout_suits_right_alt(devices("de", "").as_bytes()),
            Some(false)
        );
        assert_eq!(
            layout_suits_right_alt(devices("us", "intl").as_bytes()),
            Some(false)
        );
        assert_eq!(layout_suits_right_alt(b"not json"), None);
    }

    #[test]
    fn writing_replaces_earlier_binds_and_keeps_everything_else() {
        let original = "\
# Apps
bind = SUPER, RETURN, exec, kitty
# bind = SUPER, D, exec, opendictate toggle
bind = SUPER, D, exec, opendictate toggle

";
        let (text, replaced) = with_bind(original, Choice::F9, Style::Classic);
        assert_eq!(replaced, 1);
        assert_eq!(
            text,
            "\
# Apps
bind = SUPER, RETURN, exec, kitty
# bind = SUPER, D, exec, opendictate toggle

# OpenDictate: start and stop dictation (opendictate setup)
bind = , F9, exec, opendictate toggle
"
        );
        // Running it again changes nothing.
        let (again, replaced) = with_bind(&text, Choice::F9, Style::Classic);
        assert_eq!(again, text);
        assert_eq!(replaced, 1);
    }

    #[test]
    fn a_lua_file_ending_in_return_keeps_its_return_last() {
        let original = "local o = require(\"omarchy\")\no.bind(\"SUPER + RETURN\", \"Terminal\", \"kitty\")\n\nreturn o\n-- end\n";
        let (text, _) = with_bind(original, Choice::SuperD, Style::OmarchyLua);
        assert_eq!(
            text,
            "local o = require(\"omarchy\")\no.bind(\"SUPER + RETURN\", \"Terminal\", \"kitty\")\n\n-- OpenDictate: start and stop dictation (opendictate setup)\no.bind(\"SUPER + D\", \"OpenDictate\", \"opendictate toggle\")\n\nreturn o\n-- end\n"
        );
        let (again, _) = with_bind(&text, Choice::SuperD, Style::OmarchyLua);
        assert_eq!(again, text);
    }

    #[test]
    fn install_keeps_a_backup_and_detects_the_omarchy_file() {
        let dir = std::env::temp_dir().join(format!("opendictate-hypr-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        assert_eq!(detect(&dir), None);
        fs::write(dir.join("hyprland.conf"), "source = ~/x.conf\n").unwrap();
        assert_eq!(detect(&dir).unwrap().style, Style::Classic);
        let original = "o.bind(\"SUPER + RETURN\", \"Terminal\", \"kitty\")\n";
        fs::write(dir.join("bindings.lua"), original).unwrap();
        let target = detect(&dir).unwrap();
        assert_eq!(target.style, Style::OmarchyLua);
        let installed = install(Choice::SuperD, &target).unwrap();
        assert_eq!(fs::read_to_string(&installed.backup).unwrap(), original);
        let written = fs::read_to_string(&target.path).unwrap();
        assert!(written.starts_with(original));
        assert!(written.ends_with(
            "-- OpenDictate: start and stop dictation (opendictate setup)\no.bind(\"SUPER + D\", \"OpenDictate\", \"opendictate toggle\")\n"
        ));
        let plain_lua = Target {
            path: dir.join("hyprland.lua"),
            style: Style::Lua,
        };
        assert!(install(Choice::SuperD, &plain_lua).is_err());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn install_and_restore_replace_the_file_behind_a_symlink() {
        let dir = std::env::temp_dir().join(format!("opendictate-link-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(dir.join("dotfiles")).unwrap();
        let real = dir.join("dotfiles").join("bindings.conf");
        let original = "bind = SUPER, RETURN, exec, kitty\nbind = , F9, exec, opendictate toggle\n";
        fs::write(&real, original).unwrap();
        let link = dir.join("bindings.conf");
        std::os::unix::fs::symlink(&real, &link).unwrap();
        let target = Target {
            path: link.clone(),
            style: Style::Classic,
        };
        let installed = install(Choice::SuperD, &target).unwrap();
        assert_eq!(installed.replaced, 1);
        assert!(fs::symlink_metadata(&link)
            .unwrap()
            .file_type()
            .is_symlink());
        let written = fs::read_to_string(&real).unwrap();
        assert!(written.contains("bind = SUPER, D, exec, opendictate toggle"));
        assert!(!written.contains("F9"));
        restore(&target, &installed).unwrap();
        assert!(fs::symlink_metadata(&link)
            .unwrap()
            .file_type()
            .is_symlink());
        assert_eq!(fs::read_to_string(&real).unwrap(), original);
        let leftovers: Vec<_> = fs::read_dir(dir.join("dotfiles"))
            .unwrap()
            .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
            .filter(|name| name.starts_with('.'))
            .collect();
        assert!(leftovers.is_empty(), "{leftovers:?}");
        let _ = fs::remove_dir_all(&dir);
    }
}
