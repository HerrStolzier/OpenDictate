use serde_json::json;

use crate::settings::Settings;
use crate::state::State;

// Nerd Font glyphs, as used by the default Omarchy Waybar.
const MICROPHONE: &str = "\u{f130}";
const HOURGLASS: &str = "\u{f252}";

/// Renders one Waybar custom-module JSON line. It carries only state and
/// settings, never transcript text.
pub fn render(state: State, settings: &Settings) -> String {
    let icon = match state {
        State::Idle | State::Recording => MICROPHONE,
        State::Processing | State::Delivering => HOURGLASS,
    };
    let text = match settings.target_language.as_deref() {
        Some(target) => format!("{icon} {}", target.to_ascii_uppercase()),
        None => icon.to_string(),
    };
    let activity = match state {
        State::Idle => "bereit",
        State::Recording => "Aufnahme läuft",
        State::Processing => "verarbeitet",
        State::Delivering => "liefert Text",
    };
    let translation = match settings.target_language.as_deref() {
        Some(target) => format!("Übersetzung nach {target}"),
        None => "keine Übersetzung".to_string(),
    };
    let tooltip =
        format!("OpenDictate: {activity}\n{translation}\nKlick schaltet die Übersetzung um");
    let mut classes = vec![state.as_str()];
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

    fn parse(line: &str) -> serde_json::Value {
        assert!(!line.contains('\n'), "Waybar expects one line: {line}");
        serde_json::from_str(line).unwrap()
    }

    #[test]
    fn idle_without_translation_shows_only_the_microphone() {
        let value = parse(&render(State::Idle, &Settings::default()));
        assert_eq!(value["text"], MICROPHONE);
        assert_eq!(value["class"], json!(["idle"]));
        assert!(value["tooltip"]
            .as_str()
            .unwrap()
            .contains("keine Übersetzung"));
    }

    #[test]
    fn recording_with_translation_names_the_target() {
        let mut settings = Settings::default();
        settings.set_target(Some("en".to_string()));
        let value = parse(&render(State::Recording, &settings));
        assert_eq!(value["text"], format!("{MICROPHONE} EN"));
        assert_eq!(value["class"], json!(["recording", "translating"]));
        assert!(value["tooltip"]
            .as_str()
            .unwrap()
            .contains("Aufnahme läuft"));
    }

    #[test]
    fn processing_uses_the_busy_icon() {
        let value = parse(&render(State::Processing, &Settings::default()));
        assert_eq!(value["text"], HOURGLASS);
        assert_eq!(value["alt"], "processing");
    }
}
