use std::fs::{self, OpenOptions};
use std::io::Write;
use std::os::unix::fs::OpenOptionsExt;
use std::path::Path;

use serde::{Deserialize, Serialize};

pub const DEFAULT_MODEL: &str = "gpt-transcribe";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Settings {
    pub model: String,
    pub language: Option<String>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            model: DEFAULT_MODEL.to_string(),
            language: Some("de".to_string()),
        }
    }
}

impl Settings {
    pub fn load(path: &Path) -> Result<Self, String> {
        if !path.exists() {
            return Ok(Self::default());
        }
        let data = fs::read(path).map_err(|_| "Einstellungen nicht lesbar.".to_string())?;
        let settings: Self = serde_json::from_slice(&data)
            .map_err(|_| "Einstellungen sind beschädigt.".to_string())?;
        validate_model(&settings.model)?;
        if let Some(language) = settings.language.as_deref() {
            validate_language(language)?;
        }
        Ok(settings)
    }

    pub fn save(&self, path: &Path) -> Result<(), String> {
        validate_model(&self.model)?;
        if let Some(language) = self.language.as_deref() {
            validate_language(language)?;
        }
        let parent = path
            .parent()
            .ok_or_else(|| "Einstellungen nicht speicherbar.".to_string())?;
        fs::create_dir_all(parent).map_err(|_| "Einstellungen nicht speicherbar.".to_string())?;
        let temporary = parent.join(format!(".settings-{}.tmp", std::process::id()));
        let result = (|| {
            let mut file = OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(&temporary)
                .map_err(|_| "Einstellungen nicht speicherbar.".to_string())?;
            let data = serde_json::to_vec_pretty(self)
                .map_err(|_| "Einstellungen nicht speicherbar.".to_string())?;
            file.write_all(&data)
                .and_then(|_| file.write_all(b"\n"))
                .and_then(|_| file.sync_all())
                .map_err(|_| "Einstellungen nicht speicherbar.".to_string())?;
            fs::rename(&temporary, path)
                .map_err(|_| "Einstellungen nicht speicherbar.".to_string())?;
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
        "gpt-live-transcribe" => {
            Err("Das Echtzeitmodell kann nicht hochgeladen werden.".to_string())
        }
        _ => Err("Unbekanntes Transkriptionsmodell.".to_string()),
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
        Err("Ungültiger Sprachcode.".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn realtime_model_is_rejected() {
        assert!(validate_model("gpt-live-transcribe").is_err());
        assert!(validate_model(DEFAULT_MODEL).is_ok());
    }

    #[test]
    fn settings_round_trip_without_a_secret() {
        let dir = std::env::temp_dir().join(format!("opendictate-settings-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("settings.json");
        let settings = Settings {
            model: "gpt-4o-mini-transcribe".to_string(),
            language: None,
        };
        settings.save(&path).unwrap();
        assert_eq!(Settings::load(&path).unwrap(), settings);
        let text = fs::read_to_string(&path).unwrap();
        assert!(!text.contains("api"));
        let _ = fs::remove_dir_all(&dir);
    }
}
