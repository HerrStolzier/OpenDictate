use serde_json::json;

use crate::i18n::t;
use crate::settings::Settings;
use crate::state::State;

// Blink, the OpenDictate block cursor, as a plain text glyph that every bar
// font has (U+25AE). The bar shows the state word only where it matters at a
// glance: "REC" while recording; the tooltip names every state.
const BLINK: &str = "\u{25ae}";
const REC: &str = "REC";
const BUSY: &str = "\u{2026}";

pub fn render_settings_error(state: State) -> String {
    let progress = match state {
        State::Recording => format!("{BLINK} {REC} !"),
        State::Starting | State::Processing | State::Delivering => format!("{BLINK} {BUSY} !"),
        State::Idle => format!("{BLINK} !"),
    };
    let mut classes = vec![state.as_str(), "error"];
    if state == State::Recording {
        classes.push("active");
    }
    json!({"text": progress, "tooltip": crate::tr!("Einstellungen nicht lesbar. Dienst: Einrichtung prüfen", "Settings unavailable. Service: Check setup"), "class": classes, "alt": state.as_str()}).to_string()
}

/// Renders one Waybar-style JSON line, which Waybar and the Omarchy shell
/// bar both read from a command module. It carries only state and
/// settings, never transcript text.
pub fn render(state: State, settings: &Settings) -> String {
    let mut parts = vec![BLINK.to_string()];
    match state {
        State::Idle => {}
        State::Recording => parts.push(REC.to_string()),
        State::Starting | State::Processing | State::Delivering => parts.push(BUSY.to_string()),
    }
    if let Some(target) = settings.target_language.as_deref() {
        parts.push(target.to_ascii_uppercase());
    }
    let text = parts.join(" ");
    // The state words of the brand (design/brand.md); the short start while
    // the microphone opens has none and is named plainly.
    let word = match state {
        State::Idle => t("Bereit", "Ready"),
        State::Starting => t("Mikrofon startet", "Microphone starting"),
        State::Recording => t("Hört zu", "Listening"),
        State::Processing | State::Delivering => t("Schreibt", "Writing"),
    };
    let translation = match settings.target_language.as_deref() {
        Some(target) => crate::tr!("Übersetzung nach {target}", "Translation to {target}"),
        None => crate::tr!("Keine Übersetzung", "No translation"),
    };
    let hint = t(
        "Klick schaltet die Übersetzung um",
        "Click to switch the translation",
    );
    let service = match settings.resolve_server() {
        Ok((server, _)) if server.is_custom() => crate::tr!(
            "Dienst: Eigener Server ({})",
            "Service: Custom server ({})",
            server.log_host()
        ),
        Ok(_) => crate::tr!("Dienst: OpenAI", "Service: OpenAI"),
        Err(_) => crate::tr!("Dienst: Einrichtung prüfen", "Service: Check setup"),
    };
    let tooltip = format!("OpenDictate \u{b7} {word}\n{translation}\n{service}\n{hint}");
    let mut classes = vec![state.as_str()];
    // The Omarchy shell bar highlights a command module only for `active`.
    if state == State::Recording {
        classes.push("active");
    }
    if settings.target_language.is_some() {
        classes.push("translating");
    }
    json!({
        "text": text,
        "tooltip": tooltip,
        "class": classes,
        "alt": state.as_str(),
    })
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unreadable_settings_never_claim_openai_is_selected() {
        let value = parse(&render_settings_error(State::Processing));
        assert!(value["tooltip"]
            .as_str()
            .unwrap()
            .contains("Einrichtung prüfen"));
        assert!(!value["tooltip"].as_str().unwrap().contains("OpenAI"));
        assert_eq!(value["alt"], "processing");
        let recording = parse(&render_settings_error(State::Recording));
        assert!(recording["text"].as_str().unwrap().contains("REC"));
        assert!(recording["class"]
            .as_array()
            .unwrap()
            .iter()
            .any(|class| class == "active"));
    }

    fn parse(line: &str) -> serde_json::Value {
        assert!(!line.contains('\n'), "Waybar expects one line: {line}");
        serde_json::from_str(line).unwrap()
    }

    #[test]
    fn idle_without_translation_shows_only_blink() {
        let value = parse(&render(State::Idle, &Settings::default()));
        assert_eq!(value["text"], "\u{25ae}");
        assert_eq!(value["class"], json!(["idle"]));
        let tooltip = value["tooltip"].as_str().unwrap();
        assert!(tooltip.starts_with("OpenDictate \u{b7} Bereit\n"));
        assert!(tooltip.contains("Keine Übersetzung"));
    }

    #[test]
    fn recording_with_translation_names_the_target() {
        let mut settings = Settings::default();
        settings.set_target(Some("en".to_string()));
        let value = parse(&render(State::Recording, &settings));
        assert_eq!(value["text"], "\u{25ae} REC EN");
        assert_eq!(
            value["class"],
            json!(["recording", "active", "translating"])
        );
        assert!(value["tooltip"].as_str().unwrap().contains("Hört zu"));
    }

    #[test]
    fn starting_is_not_shown_as_active_yet() {
        let value = parse(&render(State::Starting, &Settings::default()));
        assert_eq!(value["text"], "\u{25ae} \u{2026}");
        assert_eq!(value["class"], json!(["starting"]));
        assert!(value["tooltip"]
            .as_str()
            .unwrap()
            .contains("Mikrofon startet"));
    }

    #[test]
    fn processing_and_delivering_read_as_writing() {
        for state in [State::Processing, State::Delivering] {
            let value = parse(&render(state, &Settings::default()));
            assert_eq!(value["text"], "\u{25ae} \u{2026}");
            assert_eq!(value["alt"], state.as_str());
            assert!(value["tooltip"].as_str().unwrap().contains("Schreibt"));
        }
    }
}
