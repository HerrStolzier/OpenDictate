//! A local, explicit support report. Raw logs and free-form settings never
//! cross into the report; only known operational categories are retained.

use std::collections::VecDeque;
use std::fs;
use std::io::{self, Read, Write};
use std::process::Command;

use crate::settings::Settings;

const SUPPORT: &str = "https://support.opendictate.app/kontakt";

fn category(event: &str) -> Option<&'static str> {
    Some(match event {
        "transcription-failed" => "Transkription fehlgeschlagen",
        "translation-failed" => "Übersetzung fehlgeschlagen",
        "recording-failed" | "recording-stop-failed" => "Aufnahme fehlgeschlagen",
        "insert-skipped" => "Einfügen nicht bestätigt",
        "recording-kept" => "Diktat nicht zugestellt",
        "pending-cleanup-failed" => "Aufnahmebereinigung fehlgeschlagen",
        "recovery-prune-failed" => "Sicherungsbereinigung fehlgeschlagen",
        _ => return None,
    })
}

fn safe_events(log: &str) -> VecDeque<&str> {
    let mut events = VecDeque::new();
    for line in log.lines() {
        let mut words = line.split_whitespace();
        let Some(mut event) = words.next() else {
            continue;
        };
        if event.bytes().all(|byte| byte.is_ascii_digit()) {
            event = words.next().unwrap_or("");
        }
        if category(event).is_some() {
            events.push_back(event);
            if events.len() > 30 {
                events.pop_front();
            }
        }
    }
    events
}

fn encode(text: &str) -> String {
    let mut encoded = String::new();
    for byte in text.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'*' | b'-' | b'.' | b'_' => {
                encoded.push(byte as char)
            }
            b' ' => encoded.push('+'),
            _ => encoded.push_str(&format!("%{byte:02X}")),
        }
    }
    encoded
}

fn yes(value: bool) -> &'static str {
    if value {
        "yes"
    } else {
        "no"
    }
}

fn summary(settings: &Settings, custom: bool, loopback: bool, key: Option<bool>) -> String {
    let target = match settings.target_language.as_deref() {
        None => "off",
        Some(
            language @ ("de" | "en" | "fr" | "es" | "it" | "pt" | "nl" | "pl" | "ja" | "ko" | "zh"
            | "ar" | "ru"),
        ) => language,
        Some(_) => "other",
    };
    let model = if crate::settings::validate_model(&settings.model).is_ok() {
        settings.model.as_str()
    } else {
        "custom"
    };
    format!("custom_server={}\nloopback={}\napi_key={}\nmodel={model}\ntranslation={}\ntarget={target}\nshortcut={}\nauto_insert={}\nvocabulary_entries={}",
        yes(custom), yes(loopback), key.map(yes).unwrap_or("unknown"), yes(settings.target_language.is_some()), settings.shortcut_mode.name(), yes(settings.auto_insert), settings.vocabulary.len())
}

fn build(app: &str, system: &str, german: bool, summary: &str, log: &str) -> (String, String) {
    let mut events = safe_events(log);
    let error = events
        .back()
        .and_then(|event| category(event))
        .unwrap_or("");
    loop {
        let mut diagnostic = summary.to_string();
        for event in &events {
            diagnostic.push('\n');
            diagnostic.push_str(event);
        }
        let address = format!(
            "{SUPPORT}?lang={}#app={}&system={}&fehler={}&diagnose={}",
            if german { "de" } else { "en" },
            encode(&app.chars().take(100).collect::<String>()),
            encode(&system.chars().take(150).collect::<String>()),
            encode(error),
            encode(&diagnostic)
        );
        if diagnostic.chars().count() <= 4000 && address.len() <= 12000 {
            return (
                address,
                format!("app: {app}\nsystem: {system}\nfehler: {error}\ndiagnose:\n{diagnostic}"),
            );
        }
        // The production summary and typed metadata are bounded. This fallback
        // also keeps the pure builder bounded for a too-long supplied summary.
        if events.pop_front().is_none() {
            return build(
                app,
                system,
                german,
                &summary.chars().take(500).collect::<String>(),
                "",
            );
        }
    }
}

fn system_description(os_release: &str, hyprland: bool) -> String {
    let value = |key: &str| {
        os_release.lines().find_map(|line| {
            line.strip_prefix(&format!("{key}="))
                .map(|value| value.trim_matches('"'))
        })
    };
    let distribution = match value("ID").unwrap_or("") {
        "arch" => "Arch",
        "ubuntu" => "Ubuntu",
        "debian" => "Debian",
        "fedora" => "Fedora",
        "opensuse-tumbleweed" => "openSUSE",
        "nixos" => "NixOS",
        _ => "Linux",
    };
    let version = value("VERSION_ID")
        .filter(|value| {
            value.len() <= 24
                && value
                    .bytes()
                    .all(|byte| byte.is_ascii_digit() || byte == b'.')
        })
        .unwrap_or("");
    format!(
        "{distribution} {version} ({}, {})",
        std::env::consts::ARCH,
        if hyprland {
            "Hyprland"
        } else {
            "unknown compositor"
        }
    )
}

pub fn run(print_only: bool) -> Result<(), String> {
    let saved = Settings::load(&crate::paths::settings_path().map_err(crate::path_error)?)?;
    let (settings, server) = saved.for_request()?;
    let key = crate::keyring::status().ok().map(|status| status.0);
    let log_path = crate::paths::worker_log_path().map_err(crate::path_error)?;
    let mut log = String::new();
    if let Ok(file) = fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW)
        .open(log_path)
    {
        let _ = file.take(2 * 1024 * 1024).read_to_string(&mut log);
    }
    let os_release = fs::read_to_string("/etc/os-release").unwrap_or_default();
    let system = system_description(
        &os_release,
        std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some(),
    );
    let app = format!("{} {}", env!("CARGO_PKG_NAME"), env!("CARGO_PKG_VERSION"));
    let (address, preview) = build(
        &app,
        &system,
        crate::i18n::is_german(),
        &summary(&settings, server.is_custom(), !server.sends_api_key(), key),
        &log,
    );
    if print_only {
        println!("{address}");
        return Ok(());
    }
    println!("{preview}");
    print!(
        "{}",
        crate::i18n::t(
            "Bericht im Browser öffnen? [j/N] ",
            "Open report in your browser? [y/N] "
        )
    );
    io::stdout().flush().map_err(crate::path_error)?;
    let mut answer = String::new();
    io::stdin()
        .read_line(&mut answer)
        .map_err(crate::path_error)?;
    let accepted = if crate::i18n::is_german() { "j" } else { "y" };
    if !answer.trim().eq_ignore_ascii_case(accepted) {
        return Ok(());
    }
    if std::env::var_os("WAYLAND_DISPLAY").is_none() && std::env::var_os("DISPLAY").is_none()
        || !Command::new("xdg-open")
            .arg(&address)
            .status()
            .is_ok_and(|status| status.success())
    {
        println!("{address}");
    }
    Ok(())
}

use std::os::unix::fs::OpenOptionsExt;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shared_address_and_private_log_details() {
        let fixture: serde_json::Value =
            serde_json::from_str(include_str!("../../fixtures/report/example.json")).unwrap();
        let log = fixture["logs"]
            .as_array()
            .unwrap()
            .iter()
            .map(|line| line.as_str().unwrap())
            .collect::<Vec<_>>()
            .join("\n");
        let settings = Settings::default();
        let (address, _) = build(
            "Product 0.1.0",
            "Windows 10.0.26100 (x64)",
            true,
            &summary(&settings, true, true, Some(false)),
            &log,
        );
        assert_eq!(address, fixture["address"].as_str().unwrap());
        let log = "transcription-failed secret=sk-private host=private.invalid transcript=private-text\nwindow private-title\nclipboard private-content\naudio /private/audio.wav\n".repeat(100);
        let (address, preview) = build(
            "Product 0.1.0",
            "Linux",
            true,
            &summary(&settings, true, true, None),
            &log,
        );
        assert!(!address.contains("private") && !preview.contains("private"));
        assert!(address.len() <= 12000);
        assert_eq!(preview.matches("\ntranscription-failed").count(), 30);
        assert_eq!(encode("Grüße +&🧪"), "Gr%C3%BC%C3%9Fe+%2B%26%F0%9F%A7%AA");
    }

    #[test]
    fn unknown_errors_stay_empty_and_untrusted_os_metadata_is_not_copied() {
        let settings = Settings {
            target_language: Some("fr".to_string()),
            ..Settings::default()
        };
        assert!(summary(&settings, false, false, None).contains("target=fr"));
        let settings = Settings {
            shortcut_mode: crate::settings::ShortcutMode::Hold,
            vocabulary: vec!["Private vocabulary".to_string()],
            ..settings
        };
        let details = summary(&settings, false, false, None);
        assert!(details.contains("shortcut=hold") && details.contains("vocabulary_entries=1"));
        assert!(!details.contains("Private"));
        let (_, preview) = build("Product", "Linux", true, "", "raw transcript");
        assert!(preview.contains("fehler: \n"));
        assert!(
            !system_description("ID=secret-host\nVERSION_ID=sk-private", false).contains("private")
        );
        let (address, _) = build(
            "Product",
            "Linux",
            true,
            &"ü".repeat(4000),
            &"transcription-failed\n".repeat(40),
        );
        assert!(address.len() <= 12000);
    }
}
