use std::io::Read;
use std::path::Path;
use std::time::Duration;

use serde::Deserialize;

use crate::server::Server;
use crate::settings::{validate_model_for, Settings};

const MAX_UPLOAD_BYTES: usize = 25 * 1_024 * 1_024;
/// Waiting time for the provider's answer on top of the upload. A request
/// that stalls because the network is gone ends after this budget instead
/// of an open-ended read timeout. A write blocked when the network drops
/// can still last up to the time that was left at connect.
const RESPONSE_BUDGET: Duration = Duration::from_secs(15);
/// A custom server is often a model on this computer's CPU, which needs far
/// longer for a 90-second recording than OpenAI does.
const CUSTOM_RESPONSE_BUDGET: Duration = Duration::from_secs(120);
/// Upload allowance for a slow uplink of about 2 Mbit/s.
const SLOW_UPLINK_BYTES_PER_SECOND: u64 = 250_000;

pub struct Transcriber {
    server: Server,
    url: String,
    agent: ureq::Agent,
    response_budget: Duration,
}

impl Transcriber {
    pub fn new(server: &Server) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(10))
            .redirects(0)
            .build();
        Self {
            server: server.clone(),
            url: server.transcription_url(),
            agent,
            response_budget: if server.is_custom() {
                CUSTOM_RESPONSE_BUDGET
            } else {
                RESPONSE_BUDGET
            },
        }
    }

    pub fn transcribe(
        &self,
        audio_path: &Path,
        api_key: Option<&str>,
        settings: &Settings,
    ) -> Result<String, String> {
        validate_model_for(&settings.model, &self.server)?;
        self.key_to_send(api_key)?;
        let audio = std::fs::read(audio_path)
            .map_err(|_| crate::tr!("Aufnahme nicht lesbar.", "Recording unreadable."))?;
        self.transcribe_bytes(&audio, api_key, settings)
    }

    pub fn transcribe_bytes(
        &self,
        audio: &[u8],
        api_key: Option<&str>,
        settings: &Settings,
    ) -> Result<String, String> {
        validate_model_for(&settings.model, &self.server)?;
        let api_key = self.key_to_send(api_key)?;
        if audio.is_empty() || audio.len() > MAX_UPLOAD_BYTES {
            return Err(crate::tr!(
                "Aufnahme hat eine ungültige Größe.",
                "Recording has an invalid size."
            ));
        }
        let boundary = format!("OpenDictateBoundary{}", std::process::id());
        let body = multipart_body(&boundary, audio, settings);
        let mut request = self
            .agent
            .post(&self.url)
            .timeout(request_timeout(self.response_budget, body.len()))
            .set(
                "Content-Type",
                &format!("multipart/form-data; boundary={boundary}"),
            );
        if let Some(api_key) = api_key {
            request = request.set("Authorization", &format!("Bearer {api_key}"));
        }
        decode_response(request.send_bytes(&body), &self.server)
    }

    /// The key for this server: required for OpenAI and other remote
    /// servers, never sent to an address on this computer.
    fn key_to_send<'a>(&self, api_key: Option<&'a str>) -> Result<Option<&'a str>, String> {
        if !self.server.sends_api_key() {
            return Ok(None);
        }
        match api_key {
            Some(api_key) if !api_key.is_empty() => Ok(Some(api_key)),
            _ => Err(crate::tr!("API-Schlüssel fehlt.", "API key is missing.")),
        }
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

fn decode_response(
    response: Result<ureq::Response, ureq::Error>,
    server: &Server,
) -> Result<String, String> {
    let response = match response {
        Ok(response) => response,
        Err(ureq::Error::Status(status, response)) => {
            let mut ignored = Vec::new();
            let _ = response
                .into_reader()
                .take(16 * 1_024)
                .read_to_end(&mut ignored);
            return Err(match status {
                401 | 403 if !server.sends_api_key() => crate::tr!(
                    "Der Server verlangt eine Anmeldung; an Adressen auf diesem Rechner sendet OpenDictate keinen API-Schlüssel.",
                    "The server asks for a login; OpenDictate sends no API key to addresses on this computer."
                ),
                401 => crate::tr!("API-Schlüssel ist ungültig.", "API key is invalid."),
                404 if server.is_custom() => crate::tr!(
                    "Der Server kennt diese Adresse oder dieses Modell nicht. Server-Adresse (mit /v1) und Modellnamen prüfen.",
                    "The server does not know this address or model. Check the server address (with /v1) and the model name."
                ),
                413 => crate::tr!(
                    "Aufnahme ist für den Upload zu groß.",
                    "Recording is too large to upload."
                ),
                429 if server.is_custom() => crate::tr!(
                    "Der Server ist ausgelastet. Bitte später erneut versuchen.",
                    "The server is busy. Please try again later."
                ),
                429 => crate::tr!(
                    "OpenAI-Limit erreicht. Bitte später erneut versuchen.",
                    "OpenAI limit reached. Please try again later."
                ),
                _ => crate::tr!("Transkription fehlgeschlagen.", "Transcription failed."),
            });
        }
        Err(ureq::Error::Transport(_)) if server.is_custom() => {
            return Err(crate::tr!(
                "Netzwerkfehler: Eigener Server ({}) nicht erreichbar oder zu langsam.",
                "Network error: custom server ({}) unreachable or too slow.",
                server.log_host()
            ))
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
        .map_err(|_| invalid_response())?;
    #[derive(Deserialize)]
    struct Response {
        text: String,
    }
    let parsed: Response = serde_json::from_slice(&data).map_err(|_| invalid_response())?;
    Ok(parsed.text.trim().to_string())
}

fn invalid_response() -> String {
    crate::tr!(
        "Ungültige Antwort vom Transkriptionsdienst.",
        "Invalid response from the transcription service."
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_http::{serve, serve_without_answer};

    /// OpenAI's rules, but talking to the local stub.
    fn openai_stub(endpoint: &str) -> Transcriber {
        let mut transcriber = Transcriber::new(&Server::openai());
        transcriber.url = endpoint.to_string();
        transcriber
    }

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
        let text = openai_stub(&endpoint)
            .transcribe(&path, Some("test-key"), &settings)
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
        let error = openai_stub(&endpoint)
            .transcribe(&path, Some("test-key"), &Settings::default())
            .unwrap_err();
        assert!(error.contains("ungültig"));
        assert!(!error.contains("private"));
        server.join().unwrap();
        let _ = std::fs::remove_file(path);
    }

    /// The provider contract shared with macOS and Windows
    /// (`fixtures/provider/`): request field order, the success response
    /// and the user-facing message for each error. A new fixture in
    /// `cases.json` also needs its file in `fixture` and its status in
    /// `status_line`.
    mod contract {
        use super::*;

        const CASES: &str = include_str!("../../fixtures/provider/cases.json");

        fn fixture(name: &str) -> &'static str {
            match name {
                "response-ok.json" => include_str!("../../fixtures/provider/response-ok.json"),
                "error-401.json" => include_str!("../../fixtures/provider/error-401.json"),
                "error-413.json" => include_str!("../../fixtures/provider/error-413.json"),
                "error-429.json" => include_str!("../../fixtures/provider/error-429.json"),
                "error-500.json" => include_str!("../../fixtures/provider/error-500.json"),
                other => panic!("fixtures/provider/{other} is not wired into the Linux test"),
            }
        }

        fn status_line(status: u64) -> String {
            let reason = match status {
                200 => "OK",
                401 => "Unauthorized",
                413 => "Payload Too Large",
                429 => "Too Many Requests",
                500 => "Internal Server Error",
                other => panic!("no reason phrase for {other}"),
            };
            format!("{status} {reason}")
        }

        fn cases() -> serde_json::Value {
            serde_json::from_str(CASES).unwrap()
        }

        #[test]
        fn success_fixture_is_trimmed_and_fields_keep_their_order() {
            let success = &cases()["success"];
            let (endpoint, server) = serve(
                &status_line(success["status"].as_u64().unwrap()),
                fixture(success["file"].as_str().unwrap()),
            );
            let path = audio_file("contract-ok");
            let settings = Settings {
                language: Some("de".to_string()),
                ..Settings::default()
            };
            let text = openai_stub(&endpoint)
                .transcribe(&path, Some("test-key"), &settings)
                .unwrap();
            assert_eq!(text, success["text"].as_str().unwrap());
            let request = server.join().unwrap();
            let request = String::from_utf8_lossy(&request);
            let position = |field: &str| {
                request
                    .find(&format!("name=\"{field}\""))
                    .unwrap_or_else(|| panic!("field {field} missing"))
            };
            assert!(position("model") < position("response_format"));
            assert!(position("response_format") < position("languages[]"));
            assert!(position("languages[]") < position("file"));
            assert!(request.contains("filename=\"recording.wav\"\r\nContent-Type: audio/wav"));
            let _ = std::fs::remove_file(path);
        }

        #[test]
        fn every_error_fixture_has_its_own_linux_message() {
            let cases = cases();
            let errors = cases["errors"].as_array().unwrap();
            assert!(!errors.is_empty());
            for case in errors {
                let file = case["file"].as_str().unwrap();
                let expected = case["linux_message_contains"]
                    .as_str()
                    .unwrap_or_else(|| panic!("{file} has no linux_message_contains"));
                let body = fixture(file);
                let (endpoint, server) =
                    serve(&status_line(case["status"].as_u64().unwrap()), body);
                let path = audio_file("contract-error");
                let error = openai_stub(&endpoint)
                    .transcribe(&path, Some("test-key"), &Settings::default())
                    .unwrap_err();
                assert!(error.contains(expected), "{file}: {error}");
                let provider: serde_json::Value = serde_json::from_str(body).unwrap();
                let provider_text = provider["error"]["message"].as_str().unwrap();
                assert!(!error.contains(provider_text), "{file} leaks: {error}");
                server.join().unwrap();
                let _ = std::fs::remove_file(path);
            }
        }
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
        let mut transcriber = openai_stub(&endpoint);
        transcriber.response_budget = Duration::from_millis(300);
        let started = std::time::Instant::now();
        let error = transcriber
            .transcribe(&path, Some("test-key"), &Settings::default())
            .unwrap_err();
        assert!(error.contains("Netzwerkfehler"));
        assert!(started.elapsed() < Duration::from_secs(5));
        server.join().unwrap();
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn local_server_gets_no_key_and_free_model_names() {
        let (endpoint, server) = serve("200 OK", r#"{"text":"Hallo lokal."}"#);
        let path = audio_file("local");
        let local = Server::parse(&format!("{endpoint}/v1")).unwrap();
        let settings = Settings {
            model: "Systran/faster-whisper-small".to_string(),
            ..Settings::default()
        };
        let text = Transcriber::new(&local)
            .transcribe(&path, Some("test-key"), &settings)
            .unwrap();
        assert_eq!(text, "Hallo lokal.");
        let request = server.join().unwrap();
        let request = String::from_utf8_lossy(&request);
        assert!(request.starts_with("POST /v1/audio/transcriptions "));
        assert!(!request.to_ascii_lowercase().contains("authorization"));
        assert!(!request.contains("test-key"));
        assert!(request.contains("Systran/faster-whisper-small"));
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn local_server_works_without_any_key() {
        let (endpoint, server) = serve("200 OK", r#"{"text":"Ohne Schlüssel."}"#);
        let local = Server::parse(&format!("{endpoint}/v1")).unwrap();
        let text = Transcriber::new(&local)
            .transcribe_bytes(b"RIFF-test-audio", None, &Settings::default())
            .unwrap();
        assert_eq!(text, "Ohne Schlüssel.");
        server.join().unwrap();
    }

    #[test]
    fn openai_needs_a_key_and_a_known_model() {
        let transcriber = Transcriber::new(&Server::openai());
        let error = transcriber
            .transcribe_bytes(b"RIFF-test-audio", None, &Settings::default())
            .unwrap_err();
        assert!(error.contains("fehlt"));
        let settings = Settings {
            model: "Systran/faster-whisper-small".to_string(),
            ..Settings::default()
        };
        assert!(transcriber
            .transcribe_bytes(b"RIFF-test-audio", Some("test-key"), &settings)
            .is_err());
    }

    #[test]
    fn unreachable_local_server_is_named_by_host() {
        // Nothing listens on port 9 of this computer.
        let local = Server::parse("http://127.0.0.1:9/v1").unwrap();
        let error = Transcriber::new(&local)
            .transcribe_bytes(b"RIFF-test-audio", None, &Settings::default())
            .unwrap_err();
        assert!(error.contains("Netzwerkfehler"));
        assert!(error.contains("127.0.0.1"));
        assert!(!error.contains("/v1"));
    }

    #[test]
    fn custom_server_errors_point_to_address_and_model() {
        let (endpoint, server) = serve("404 Not Found", r#"{"error":"private detail"}"#);
        let local = Server::parse(&format!("{endpoint}/v1")).unwrap();
        let error = Transcriber::new(&local)
            .transcribe_bytes(b"RIFF-test-audio", None, &Settings::default())
            .unwrap_err();
        assert!(error.contains("/v1"));
        assert!(!error.contains("private"));
        server.join().unwrap();
    }
}
