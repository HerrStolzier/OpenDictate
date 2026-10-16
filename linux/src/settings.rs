use std::fs::{self, OpenOptions};
use std::io::Write;
use std::os::unix::fs::OpenOptionsExt;
use std::path::Path;

use serde::{Deserialize, Serialize};

pub const DEFAULT_MODEL: &str = "gpt-transcribe";
pub const DEFAULT_TRANSLATION_MODEL: &str = "gpt-5.4-mini";
const DEFAULT_TOGGLE_TARGET: &str = "en";

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ShortcutMode {
    #[default]
    Tap,
    Hold,
}

impl ShortcutMode {
    pub fn name(self) -> &'static str {
        match self {
            Self::Tap => "tap",
            Self::Hold => "hold",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Service {
    Openai,
    Custom,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Settings {
    pub model: String,
    pub language: Option<String>,
    /// Translation target; `None` delivers the transcript unchanged.
    #[serde(default)]
    pub target_language: Option<String>,
    #[serde(default = "default_translation_model")]
    pub translation_model: String,
    /// Last chosen target, restored when translation is toggled back on.
    #[serde(default)]
    pub last_target_language: Option<String>,
    /// Paste into the window captured at recording start when it is still
    /// frontmost. Retry never pastes.
    #[serde(default = "default_auto_insert")]
    pub auto_insert: bool,
    /// Custom server ("Eigener Server"): base URL including `/v1`. `None`
    /// uses `OPENAI_BASE_URL` when set, otherwise OpenAI.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub server: Option<String>,
    /// Explicit local vocabulary, never learned automatically.
    #[serde(default)]
    pub vocabulary: Vec<String>,
    #[serde(default)]
    pub shortcut_mode: ShortcutMode,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub service: Option<Service>,
    #[serde(default = "default_custom_model")]
    pub custom_model: String,
    #[serde(default = "default_translation_model")]
    pub custom_translation_model: String,
}

fn default_custom_model() -> String {
    DEFAULT_MODEL.to_string()
}

fn default_auto_insert() -> bool {
    true
}

fn default_translation_model() -> String {
    DEFAULT_TRANSLATION_MODEL.to_string()
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            model: DEFAULT_MODEL.to_string(),
            // German systems keep German as the spoken language; elsewhere
            // the language is detected.
            language: crate::i18n::is_german().then(|| "de".to_string()),
            target_language: None,
            translation_model: default_translation_model(),
            last_target_language: None,
            auto_insert: default_auto_insert(),
            server: None,
            vocabulary: Vec::new(),
            shortcut_mode: ShortcutMode::Tap,
            service: None,
            custom_model: default_custom_model(),
            custom_translation_model: default_translation_model(),
        }
    }
}

impl Settings {
    pub fn load(path: &Path) -> Result<Self, String> {
        if !path.exists() {
            return Ok(Self::default());
        }
        let data = fs::read(path).map_err(|_| {
            crate::tr!(
                "Einstellungen konnten nicht gelesen werden.",
                "Settings could not be read."
            )
        })?;
        let value: serde_json::Value = serde_json::from_slice(&data).map_err(|_| {
            crate::tr!(
                "Einstellungen sind beschädigt.",
                "Settings file is corrupted."
            )
        })?;
        let legacy_models = value.get("custom_model").is_none();
        let mut settings: Self = serde_json::from_value(value).map_err(|_| {
            crate::tr!(
                "Einstellungen sind beschädigt.",
                "Settings file is corrupted."
            )
        })?;
        if legacy_models
            && settings.service.is_none()
            && (settings.server.is_some()
                || std::env::var(crate::server::BASE_URL_ENV)
                    .is_ok_and(|value| !value.trim().is_empty()))
        {
            settings.custom_model.clone_from(&settings.model);
            settings
                .custom_translation_model
                .clone_from(&settings.translation_model);
            if validate_model(&settings.model).is_err() {
                settings.model = DEFAULT_MODEL.to_string();
            }
            settings.translation_model = default_translation_model();
            // Only a stored address makes an explicit custom choice. The
            // environment keeps its existing precedence and lifetime.
            if settings.server.is_some() {
                settings.service = Some(Service::Custom);
            }
        }
        settings.validate()?;
        Ok(settings)
    }

    fn validate(&self) -> Result<(), String> {
        validate_vocabulary(&self.vocabulary)?;
        // Which models a server offers is checked when it is used: a custom
        // server names its models freely, OpenAI only takes the known ones.
        validate_model(&self.model)?;
        validate_model_name(&self.custom_model)?;
        validate_translation_model(&self.translation_model)?;
        validate_translation_model(&self.custom_translation_model)?;
        if self.service == Some(Service::Custom) && self.server.is_none() {
            return Err(crate::tr!(
                "Kein eigener Server gespeichert.",
                "No custom server stored."
            ));
        }
        if let Some(server) = self.server.as_deref() {
            crate::server::Server::parse(server).map_err(|error| {
                crate::tr!(
                    "{error} Korrigiere die gespeicherte Server-Adresse in ~/.config/opendictate/settings.json oder lösch die Zeile \"server\".",
                    "{error} Fix the stored server address in ~/.config/opendictate/settings.json or delete the \"server\" line."
                )
            })?;
        }
        for language in [
            &self.language,
            &self.target_language,
            &self.last_target_language,
        ]
        .into_iter()
        .flatten()
        {
            validate_language(language)?;
        }
        Ok(())
    }

    /// Stored custom address wins over the environment. Choosing OpenAI
    /// ignores the stored address but retains the legacy environment override.
    pub fn resolve_server(&self) -> Result<(crate::server::Server, crate::server::Source), String> {
        let stored = if self.service == Some(Service::Openai) {
            None
        } else {
            self.server.as_deref()
        };
        if self.service == Some(Service::Custom) && stored.is_none() {
            return Err(crate::tr!(
                "Kein eigener Server gespeichert.",
                "No custom server stored."
            ));
        }
        crate::server::Server::resolve(stored)
    }

    pub fn for_request(&self) -> Result<(Self, crate::server::Server), String> {
        let (server, _) = self.resolve_server()?;
        let mut request = self.clone();
        if server.is_custom() {
            request.model.clone_from(&self.custom_model);
            request
                .translation_model
                .clone_from(&self.custom_translation_model);
        }
        Ok((request, server))
    }

    pub fn choose_service(&mut self, service: Service) -> Result<(), String> {
        if service == Service::Custom && self.server.is_none() {
            return Err(crate::tr!(
                "Kein eigener Server gespeichert.",
                "No custom server stored."
            ));
        }
        self.service = Some(service);
        Ok(())
    }

    /// Sets or clears the translation target and remembers an explicit
    /// choice for [`Settings::toggle_target`].
    pub fn set_target(&mut self, target: Option<String>) {
        if target.is_some() {
            self.last_target_language.clone_from(&target);
        }
        self.target_language = target;
    }

    /// Switches translation off, or back on with the last chosen target
    /// (English when none was chosen yet).
    pub fn toggle_target(&mut self) {
        match self.target_language.take() {
            Some(target) => self.last_target_language = Some(target),
            None => {
                let target = self
                    .last_target_language
                    .clone()
                    .unwrap_or_else(|| DEFAULT_TOGGLE_TARGET.to_string());
                self.set_target(Some(target));
            }
        }
    }

    pub fn save(&self, path: &Path) -> Result<(), String> {
        self.validate()?;
        let parent = path.parent().ok_or_else(|| {
            crate::tr!(
                "Einstellungen konnten nicht gespeichert werden.",
                "Settings could not be saved."
            )
        })?;
        fs::create_dir_all(parent).map_err(|_| {
            crate::tr!(
                "Einstellungen konnten nicht gespeichert werden.",
                "Settings could not be saved."
            )
        })?;
        let temporary = parent.join(format!(".settings-{}.tmp", std::process::id()));
        let result = (|| {
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&temporary)
                .map_err(|_| {
                    crate::tr!(
                        "Einstellungen konnten nicht gespeichert werden.",
                        "Settings could not be saved."
                    )
                })?;
            let data = serde_json::to_vec_pretty(self).map_err(|_| {
                crate::tr!(
                    "Einstellungen konnten nicht gespeichert werden.",
                    "Settings could not be saved."
                )
            })?;
            file.write_all(&data)
                .and_then(|_| file.write_all(b"\n"))
                .and_then(|_| file.sync_all())
                .map_err(|_| {
                    crate::tr!(
                        "Einstellungen konnten nicht gespeichert werden.",
                        "Settings could not be saved."
                    )
                })?;
            fs::rename(&temporary, path).map_err(|_| {
                crate::tr!(
                    "Einstellungen konnten nicht gespeichert werden.",
                    "Settings could not be saved."
                )
            })?;
            Ok(())
        })();
        if result.is_err() {
            let _ = fs::remove_file(&temporary);
        }
        result
    }
}

pub fn validate_model(model: &str) -> Result<(), String> {
    match model {
        "gpt-transcribe" | "gpt-4o-mini-transcribe" | "gpt-4o-transcribe" | "whisper-1" => Ok(()),
        "gpt-live-transcribe" => Err(crate::tr!(
            "Das Echtzeitmodell funktioniert mit OpenDictate nicht. Wähl ein anderes Modell.",
            "The realtime model does not work with OpenDictate. Pick another model."
        )),
        _ => Err(crate::tr!(
            "Unbekanntes Transkriptionsmodell.",
            "Unknown transcription model."
        )),
    }
}

/// Checks a transcription model for the server that will receive it.
pub fn validate_model_for(model: &str, server: &crate::server::Server) -> Result<(), String> {
    if server.is_custom() {
        validate_model_name(model)
    } else {
        validate_model(model)
    }
}

/// Syntax of a model name as custom servers use them, e.g.
/// `Systran/faster-whisper-small` or `llama3.1:8b`.
fn is_model_name(model: &str) -> bool {
    !model.is_empty()
        && model.len() <= 128
        && !model.starts_with(['.', '/'])
        && !model.contains("..")
        && model.chars().all(|character| {
            character.is_ascii_alphanumeric() || matches!(character, '-' | '.' | '_' | ':' | '/')
        })
}

pub fn validate_model_name(model: &str) -> Result<(), String> {
    if is_model_name(model) {
        Ok(())
    } else {
        Err(crate::tr!("Ungültiger Modellname.", "Invalid model name."))
    }
}

pub fn validate_translation_model(model: &str) -> Result<(), String> {
    if is_model_name(model) {
        Ok(())
    } else {
        Err(crate::tr!(
            "Ungültiges Übersetzungsmodell.",
            "Invalid translation model."
        ))
    }
}

pub fn validate_language(language: &str) -> Result<(), String> {
    let valid = !language.is_empty()
        && language.len() <= 16
        && language
            .chars()
            .all(|character| character.is_ascii_alphanumeric() || character == '-');
    if valid {
        Ok(())
    } else {
        Err(crate::tr!(
            "Ungültiger Sprachcode.",
            "Invalid language code."
        ))
    }
}

/// A bounded hint rather than a dictionary: at most 64 entries and 800 UTF-8
/// bytes including separators. This is an application limit, not a tokenizer
/// guarantee for a provider; even short prompts can exceed Whisper's tokens.
pub fn validate_vocabulary(words: &[String]) -> Result<(), String> {
    if words.len() > 64
        || words.join(", ").len() > 800
        || words.iter().any(|word| {
            word.trim().is_empty() || word != word.trim() || word.chars().any(char::is_control)
        })
    {
        return Err(crate::tr!(
            "Vokabular: höchstens 64 Einträge und 800 UTF-8-Bytes. Leere Einträge und Steuerzeichen sind nicht erlaubt.",
            "Vocabulary: at most 64 entries and 800 UTF-8 bytes. Empty entries and control characters are not allowed."
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vocabulary_limits_and_failed_save_preserve_settings() {
        let dir = crate::test_support::unique_temp_dir("vocabulary");
        let path = dir.join("settings.json");
        let mut settings = Settings::default();
        settings.save(&path).unwrap();
        let before = fs::read(&path).unwrap();
        for words in [
            vec!["x".repeat(801)],
            vec!["x".to_string(); 65],
            vec!["word\n".to_string()],
            vec!["a\0b".to_string()],
            vec!["".to_string()],
            vec![" word".to_string()],
        ] {
            settings.vocabulary = words;
            assert!(settings.save(&path).is_err());
            assert_eq!(fs::read(&path).unwrap(), before);
        }
        settings.vocabulary = vec!["ä".repeat(400)];
        settings.save(&path).unwrap();
        assert_eq!(Settings::load(&path).unwrap(), settings);
        settings.vocabulary = vec!["x".to_string(); 64];
        assert!(validate_vocabulary(&settings.vocabulary).is_ok());
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn service_switch_keeps_address_and_both_model_pairs() {
        let dir = crate::test_support::unique_temp_dir("service-switch");
        let path = dir.join("settings.json");
        let mut settings = Settings {
            server: Some("http://127.0.0.1:8080/v1".to_string()),
            service: Some(Service::Custom),
            vocabulary: vec!["Hyprland".to_string()],
            shortcut_mode: ShortcutMode::Hold,
            custom_model: "large-v3".to_string(),
            custom_translation_model: "local-text".to_string(),
            ..Settings::default()
        };
        assert_eq!(settings.for_request().unwrap().0.model, "large-v3");
        settings.choose_service(Service::Openai).unwrap();
        settings.save(&path).unwrap();
        let mut loaded = Settings::load(&path).unwrap();
        assert_eq!(loaded.server, settings.server);
        assert_eq!(loaded.custom_model, "large-v3");
        assert_eq!(loaded.model, DEFAULT_MODEL);
        loaded.choose_service(Service::Custom).unwrap();
        let (request, server) = loaded.for_request().unwrap();
        assert!(server.is_custom() && !server.sends_api_key());
        assert_eq!(request.model, "large-v3");
        assert_eq!(request.vocabulary, vec!["Hyprland".to_string()]);
        assert_eq!(request.translation_model, "local-text");
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn legacy_server_models_migrate_without_losing_openai_defaults() {
        let dir = crate::test_support::unique_temp_dir("service-migration");
        let path = dir.join("settings.json");
        fs::write(&path, r#"{"model":"large-v3","language":"de","translation_model":"local-text","server":"http://127.0.0.1:8080/v1"}"#).unwrap();
        let settings = Settings::load(&path).unwrap();
        assert_eq!(settings.service, Some(Service::Custom));
        assert_eq!(settings.custom_model, "large-v3");
        assert_eq!(settings.custom_translation_model, "local-text");
        assert_eq!(settings.model, DEFAULT_MODEL);
        settings.save(&path).unwrap();
        assert_eq!(Settings::load(&path).unwrap(), settings);
        let mut invalid = Settings::default();
        assert!(invalid.choose_service(Service::Custom).is_err());
        assert_eq!(invalid.service, None);
        invalid.model = "large-v3".to_string();
        assert!(invalid.save(&path).is_err());
        assert_eq!(Settings::load(&path).unwrap(), settings);
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn realtime_model_is_rejected() {
        assert!(validate_model("gpt-live-transcribe").is_err());
        assert!(validate_model(DEFAULT_MODEL).is_ok());
    }

    #[test]
    fn settings_round_trip_without_a_secret() {
        let dir = crate::test_support::unique_temp_dir("settings");
        let path = dir.join("settings.json");
        let settings = Settings {
            model: "gpt-4o-mini-transcribe".to_string(),
            language: None,
            target_language: Some("en".to_string()),
            translation_model: "test-model".to_string(),
            last_target_language: Some("en".to_string()),
            auto_insert: false,
            server: Some("http://localhost:8080/v1".to_string()),
            vocabulary: vec!["Hyprland".to_string()],
            shortcut_mode: ShortcutMode::Hold,
            service: Some(Service::Custom),
            custom_model: "large-v3".to_string(),
            custom_translation_model: "local-text".to_string(),
        };
        settings.save(&path).unwrap();
        assert_eq!(Settings::load(&path).unwrap(), settings);
        let text = fs::read_to_string(&path).unwrap();
        assert!(!text.contains("api"));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn settings_without_translation_fields_load_untranslated() {
        let dir = crate::test_support::unique_temp_dir("settings-legacy");
        let path = dir.join("settings.json");
        fs::write(&path, r#"{"model":"gpt-transcribe","language":"de"}"#).unwrap();
        let settings = Settings::load(&path).unwrap();
        assert_eq!(settings, Settings::default());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn translation_model_rejects_unsafe_names() {
        assert!(validate_translation_model(DEFAULT_TRANSLATION_MODEL).is_ok());
        assert!(validate_translation_model("").is_err());
        assert!(validate_translation_model("model with space").is_err());
        assert!(validate_translation_model("../model").is_err());
        assert!(validate_translation_model("/model").is_err());
        assert!(validate_translation_model("llama3.1:8b").is_ok());
        assert!(validate_translation_model("qwen/qwen3-4b").is_ok());
    }

    #[test]
    fn custom_servers_take_free_model_names_openai_only_known_ones() {
        let openai = crate::server::Server::openai();
        let local = crate::server::Server::parse("http://localhost:8080/v1").unwrap();
        assert!(validate_model_for("Systran/faster-whisper-small", &local).is_ok());
        assert!(validate_model_for("Systran/faster-whisper-small", &openai).is_err());
        assert!(validate_model_for("gpt-live-transcribe", &openai).is_err());
        assert!(validate_model_for(DEFAULT_MODEL, &openai).is_ok());
        assert!(validate_model_for("model with space", &local).is_err());
    }

    #[test]
    fn an_invalid_stored_server_is_rejected_on_load() {
        let dir = crate::test_support::unique_temp_dir("settings-server");
        let path = dir.join("settings.json");
        fs::write(
            &path,
            r#"{"model":"gpt-transcribe","language":"de","server":"http://192.168.1.5/v1"}"#,
        )
        .unwrap();
        assert!(Settings::load(&path).is_err());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn toggle_restores_the_last_explicit_target() {
        let mut settings = Settings::default();
        settings.toggle_target();
        assert_eq!(settings.target_language.as_deref(), Some("en"));
        settings.set_target(Some("fr".to_string()));
        settings.toggle_target();
        assert_eq!(settings.target_language, None);
        settings.toggle_target();
        assert_eq!(settings.target_language.as_deref(), Some("fr"));
        settings.set_target(None);
        settings.toggle_target();
        assert_eq!(settings.target_language.as_deref(), Some("fr"));
    }
}
