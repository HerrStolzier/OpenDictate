use std::io::Read;
use std::path::Path;
use std::time::Duration;

use serde::Deserialize;

use crate::settings::{validate_model, Settings};

const DEFAULT_ENDPOINT: &str = "https://api.openai.com/v1/audio/transcriptions";
const MAX_UPLOAD_BYTES: usize = 25 * 1_024 * 1_024;
/// Waiting time for the provider's answer on top of the upload. A request
/// that stalls because the network is gone ends after this budget instead
/// of an open-ended read timeout. A write blocked when the network drops
/// can still last up to the time that was left at connect.
const RESPONSE_BUDGET: Duration = Duration::from_secs(15);
/// Upload allowance for a slow uplink of about 2 Mbit/s.
const SLOW_UPLINK_BYTES_PER_SECOND: u64 = 250_000;

pub struct Transcriber {
    endpoint: String,
    agent: ureq::Agent,
    response_budget: Duration,
}

impl Transcriber {
    pub fn new() -> Self {
        Self::with_endpoint(DEFAULT_ENDPOINT)
    }

    fn with_endpoint(endpoint: &str) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(10))
            .redirects(0)
            .build();
        Self {
            endpoint: endpoint.to_string(),
            agent,
            response_budget: RESPONSE_BUDGET,
        }
    }

    pub fn transcribe(
        &self,
        audio_path: &Path,
        api_key: &str,
        settings: &Settings,
    ) -> Result<String, String> {
        validate_model(&settings.model)?;
        if api_key.is_empty() {
            return Err(crate::tr!("API-Schlüssel fehlt.", "API key is missing."));
        }
        let audio = std::fs::read(audio_path)
            .map_err(|_| crate::tr!("Aufnahme nicht lesbar.", "Recording unreadable."))?;
        self.transcribe_bytes(&audio, api_key, settings)
    }

    pub fn transcribe_bytes(
        &self,
        audio: &[u8],
        api_key: &str,
        settings: &Settings,
    ) -> Result<String, String> {
        validate_model(&settings.model)?;
        if api_key.is_empty() {
            return Err(crate::tr!("API-Schlüssel fehlt.", "API key is missing."));
        }
        if audio.is_empty() || audio.len() > MAX_UPLOAD_BYTES {
            return Err(crate::tr!(
                "Aufnahme hat eine ungültige Größe.",
                "Recording has an invalid size."
            ));
        }
        let boundary = format!("OpenDictateBoundary{}", std::process::id());
        let body = multipart_body(&boundary, audio, settings);
        let response = self
            .agent
            .post(&self.endpoint)
            .timeout(request_timeout(self.response_budget, body.len()))
            .set("Authorization", &format!("Bearer {api_key}"))
            .set(
                "Content-Type",
                &format!("multipart/form-data; boundary={boundary}"),
            )
            .send_bytes(&body);
        decode_response(response)
    }
}

/// Overall limit for one request, counted from its start: connection setup,
/// upload and response share the response budget plus the time the upload
/// may take on a slow uplink. A normal connection takes well under a second.
fn request_timeout(response_budget: Duration, upload_bytes: usize) -> Duration {
    let upload_seconds = (upload_bytes as u64).div_ceil(SLOW_UPLINK_BYTES_PER_SECOND);
    response_budget + Duration::from_secs(upload_seconds)
}

fn multipart_body(boundary: &str, audio: &[u8], settings: &Settings) -> Vec<u8> {
    let mut body = Vec::new();
    push_field(&mut body, boundary, "model", &settings.model);
    push_field(&mut body, boundary, "response_format", "json");
    if let Some(language) = settings.language.as_deref() {
        let field = if settings.model == "gpt-transcribe" {
            "languages[]"
        } else {
            "language"
        };
        push_field(&mut body, boundary, field, language);
    }
    body.extend_from_slice(format!(
        "--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\nContent-Type: audio/wav\r\n\r\n"
    ).as_bytes());
    body.extend_from_slice(audio);
    body.extend_from_slice(format!("\r\n--{boundary}--\r\n").as_bytes());
    body
}

fn push_field(body: &mut Vec<u8>, boundary: &str, name: &str, value: &str) {
    body.extend_from_slice(
        format!(
            "--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n"
        )
        .as_bytes(),
    );
}

fn decode_response(response: Result<ureq::Response, ureq::Error>) -> Result<String, String> {
    let response = match response {
        Ok(response) => response,
        Err(ureq::Error::Status(status, response)) => {
            let mut ignored = Vec::new();
            let _ = response
                .into_reader()
                .take(16 * 1_024)
                .read_to_end(&mut ignored);
            return Err(match status {
                401 => crate::tr!("API-Schlüssel ist ungültig.", "API key is invalid."),
                413 => crate::tr!(
                    "Aufnahme ist für den Upload zu groß.",
                    "Recording is too large to upload."
                ),
                429 => crate::tr!(
                    "OpenAI-Limit erreicht. Bitte später erneut versuchen.",
                    "OpenAI limit reached. Please try again later."
                ),
                _ => crate::tr!("Transkription fehlgeschlagen.", "Transcription failed."),
            });
        }
        Err(ureq::Error::Transport(_)) => {
            return Err(crate::tr!(
                "Netzwerkfehler oder Zeitüberschreitung bei der Transkription.",
                "Network error or timeout during transcription."
            ))
        }
    };
    let mut data = Vec::new();
    response
        .into_reader()
        .take(1_024 * 1_024)
        .read_to_end(&mut data)
        .map_err(|_| {
            crate::tr!(
                "Ungültige Antwort von OpenAI.",
                "Invalid response from OpenAI."
            )
        })?;
    #[derive(Deserialize)]
    struct Response {
        text: String,
    }
    let parsed: Response = serde_json::from_slice(&data).map_err(|_| {
        crate::tr!(
            "Ungültige Antwort von OpenAI.",
            "Invalid response from OpenAI."
        )
    })?;
    Ok(parsed.text.trim().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_http::{serve, serve_without_answer};

    fn audio_file(case: &str) -> std::path::PathBuf {
        let path = std::env::temp_dir().join(format!(
            "opendictate-http-{}-{case}.wav",
            std::process::id()
        ));
        std::fs::write(&path, b"RIFF-test-audio").unwrap();
        path
    }

    #[test]
    fn stub_receives_multipart_and_returns_trimmed_text() {
        let (endpoint, server) = serve("200 OK", r#"{"text":"  Hallo Linux.  "}"#);
        let path = audio_file("success");
        let settings = Settings::default();
        let text = Transcriber::with_endpoint(&endpoint)
            .transcribe(&path, "test-key", &settings)
            .unwrap();
        assert_eq!(text, "Hallo Linux.");
        let request = server.join().unwrap();
        let request = String::from_utf8_lossy(&request);
        assert!(request.contains("Authorization: Bearer test-key"));
        assert!(request.contains("name=\"model\""));
        assert!(request.contains("gpt-transcribe"));
        assert!(request.contains("recording.wav"));
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn stub_error_does_not_expose_provider_body() {
        let (endpoint, server) = serve("401 Unauthorized", r#"{"error":"private detail"}"#);
        let path = audio_file("error");
        let error = Transcriber::with_endpoint(&endpoint)
            .transcribe(&path, "test-key", &Settings::default())
            .unwrap_err();
        assert!(error.contains("ungültig"));
        assert!(!error.contains("private"));
        server.join().unwrap();
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn request_timeout_grows_only_with_the_upload() {
        assert_eq!(request_timeout(RESPONSE_BUDGET, 0), RESPONSE_BUDGET);
        // 90 seconds of 48 kHz mono audio, the longest recording.
        assert_eq!(
            request_timeout(RESPONSE_BUDGET, 8_640_044),
            Duration::from_secs(50)
        );
    }

    #[test]
    fn stalled_request_ends_at_the_deadline() {
        let (endpoint, server) = serve_without_answer();
        let path = audio_file("stalled");
        let mut transcriber = Transcriber::with_endpoint(&endpoint);
        transcriber.response_budget = Duration::from_millis(300);
        let started = std::time::Instant::now();
        let error = transcriber
            .transcribe(&path, "test-key", &Settings::default())
            .unwrap_err();
        assert!(error.contains("Netzwerkfehler"));
        assert!(started.elapsed() < Duration::from_secs(5));
        server.join().unwrap();
        let _ = std::fs::remove_file(path);
    }
}
