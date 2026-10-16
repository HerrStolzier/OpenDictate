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

#[derive(Debug)]
pub struct Failure {
    message: String,
    pub custom_network: bool,
}

impl From<String> for Failure {
    fn from(message: String) -> Self {
        Self {
            message,
            custom_network: false,
        }
    }
}
impl From<Failure> for String {
    fn from(error: Failure) -> Self {
        error.message
    }
}
impl std::ops::Deref for Failure {
    type Target = str;
    fn deref(&self) -> &str {
        &self.message
    }
}
impl std::fmt::Display for Failure {
    fn fmt(&self, output: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.message.fmt(output)
    }
}

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
    ) -> Result<String, Failure> {
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
    ) -> Result<String, Failure> {
        validate_model_for(&settings.model, &self.server)?;
        let api_key = self.key_to_send(api_key)?;
        if audio.is_empty() || audio.len() > MAX_UPLOAD_BYTES {
            return Err(crate::tr!(
                "Aufnahme hat eine ungültige Größe.",
                "Recording has an invalid size."
            )
            .into());
        }
        let boundary = new_boundary()?;
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
            _ => Err(crate::tr!(
                "Der API-Schlüssel fehlt. Richte ihn mit `opendictate setup` ein.",
                "The API key is missing. Set it up with `opendictate setup`."
            )),
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

/// A multipart boundary from 16 random bytes, so neither the audio nor a
/// field value can contain it by chance or by design.
fn new_boundary() -> Result<String, Failure> {
    Ok(format!(
        "OpenDictateBoundary{}",
        crate::keyring::random_hex(16)?
    ))
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
) -> Result<String, Failure> {
    let response = match response {
        Ok(response) => response,
        Err(ureq::Error::Status(status, response)) => {
            let mut ignored = Vec::new();
            let _ = response
                .into_reader()
                .take(16 * 1_024)
                .read_to_end(&mut ignored);
            return Err((match status {
                401 | 403 if !server.sends_api_key() => crate::tr!(
                    "Dein lokaler Server will eine Anmeldung. OpenDictate schickt an Server auf diesem Rechner keinen Schlüssel – schalte die Anmeldung dort ab.",
                    "Your local server asks for a login. OpenDictate sends no key to servers on this computer – turn the login off there."
                ),
                401 => crate::tr!(
                    "Dein API-Schlüssel ist ungültig. Trag ihn mit `opendictate setup` neu ein.",
                    "Your API key is invalid. Enter it again with `opendictate setup`."
                ),
                404 if server.is_custom() => crate::tr!(
                    "Der Server kennt diese Adresse oder dieses Modell nicht. Prüf die Server-Adresse (mit /v1) und den Modellnamen.",
                    "The server does not know this address or model. Check the server address (with /v1) and the model name."
                ),
                413 => crate::tr!(
                    "Die Aufnahme ist zu groß zum Senden.",
                    "The recording is too large to send."
                ),
                429 if server.is_custom() => crate::tr!(
                    "Der Server ist ausgelastet. Versuch es später nochmal.",
                    "The server is busy. Try again later."
                ),
                429 => crate::tr!(
                    "OpenAI-Limit erreicht oder dein Guthaben ist leer. Schau in dein OpenAI-Konto.",
                    "OpenAI limit reached or your balance is empty. Check your OpenAI account."
                ),
                _ => crate::tr!("Transkription fehlgeschlagen.", "Transcription failed."),
            }).into());
        }
        Err(ureq::Error::Transport(_)) if server.is_custom() => {
            return Err(custom_network_failure(server))
        }
        Err(ureq::Error::Transport(_)) => {
            return Err(crate::tr!(
                "Keine Verbindung zum Dienst. Prüf das Internet und versuch es nochmal.",
                "No connection to the service. Check your internet connection and try again."
            )
            .into())
        }
    };
    let mut data = Vec::new();
    response
        .into_reader()
        .take(1_024 * 1_024)
        .read_to_end(&mut data)
        .map_err(|_| {
            if server.is_custom() {
                custom_network_failure(server)
            } else {
                invalid_response().into()
            }
        })?;
    #[derive(Deserialize)]
    struct Response {
        text: String,
    }
    let parsed: Response = serde_json::from_slice(&data).map_err(|_| invalid_response())?;
    Ok(crate::policy::sanitize_transcript(&parsed.text))
}

fn custom_network_failure(server: &Server) -> Failure {
    Failure { custom_network: true, message: crate::tr!(
        "Dein Server ({}) ist nicht erreichbar oder zu langsam. Prüf, ob er läuft. Mit `opendictate retry --openai` kannst du die gesicherte Aufnahme einmal an OpenAI senden.",
        "Your server ({}) is unreachable or too slow. Check that it is running. `opendictate retry --openai` sends the kept recording to OpenAI once.", server.log_host()) }
}

fn invalid_response() -> String {
    crate::tr!(
        "Der Dienst hat unerwartet geantwortet.",
        "The service gave an unexpected answer."
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_http::{serve, serve_without_answer};

    #[test]
    fn a_custom_response_body_timeout_keeps_the_explicit_retry_hint() {
        use std::io::Write;
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let stub = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut bytes = [0; 4096];
            let _ = stream.read(&mut bytes).unwrap();
            stream.write_all(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 100\r\n\r\n").unwrap();
            while matches!(stream.read(&mut bytes), Ok(count) if count > 0) {}
        });
        let server = Server::parse(&format!("http://{address}")).unwrap();
        let mut transcriber = Transcriber::new(&server);
        transcriber.response_budget = Duration::from_millis(20);
        let error = transcriber
            .transcribe_bytes(b"synthetic-audio", None, &Settings::default())
            .unwrap_err();
        assert!(error.custom_network && error.contains("retry --openai"));
        stub.join().unwrap();
    }

    #[test]
    fn only_custom_transport_errors_offer_explicit_openai_retry() {
        let (endpoint, stub) = serve_without_answer();
        let custom = Server::parse(&endpoint).unwrap();
        let mut transcriber = Transcriber::new(&custom);
        transcriber.response_budget = Duration::from_millis(20);
        let settings = Settings::default();
        let before = serde_json::to_vec(&settings).unwrap();
        let error = transcriber
            .transcribe_bytes(b"synthetic-recording", None, &settings)
            .unwrap_err();
        assert!(error.custom_network && error.contains("retry --openai"));
        stub.join().unwrap();
        let (endpoint, stub) = serve("404 Not Found", "{}");
        let server = Server::parse(&endpoint).unwrap();
        let error = Transcriber::new(&server)
            .transcribe_bytes(b"synthetic-recording", None, &settings)
            .unwrap_err();
        assert!(!error.custom_network && !error.contains("retry --openai"));
        stub.join().unwrap();
        let (endpoint, stub) = serve("200 OK", r#"{"text":"Again."}"#);
        let text = openai_stub(&endpoint)
            .transcribe_bytes(b"synthetic-recording", Some("test-key"), &settings)
            .unwrap();
        assert_eq!(text, "Again.");
        let request = String::from_utf8(stub.join().unwrap()).unwrap();
        assert!(
            request.contains("Authorization: Bearer test-key")
                && request.contains("synthetic-recording")
        );
        assert_eq!(serde_json::to_vec(&settings).unwrap(), before);
    }

    /// OpenAI's rules, but talking to the local stub.
    fn openai_stub(endpoint: &str) -> Transcriber {
        let mut transcriber = Transcriber::new(&Server::openai());
        transcriber.url = endpoint.to_string();
        transcriber
    }

    fn audio_file(case: &str) -> std::path::PathBuf {
        let path = crate::test_support::unique_temp_dir(&format!("http-{case}")).join("audio.wav");
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
        let boundary = request
            .split("boundary=")
            .nth(1)
            .and_then(|rest| rest.split("\r\n").next())
            .unwrap();
        assert!(request.contains(&format!("--{boundary}--\r\n")));
        crate::test_support::remove_temp_file(&path);
    }

    #[test]
    fn boundary_carries_sixteen_random_bytes() {
        let first = new_boundary().unwrap();
        let random = first.strip_prefix("OpenDictateBoundary").unwrap();
        assert_eq!(random.len(), 32);
        assert!(random
            .chars()
            .all(|character| character.is_ascii_hexdigit()));
        assert_ne!(first, new_boundary().unwrap());
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
        crate::test_support::remove_temp_file(&path);
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
            crate::test_support::remove_temp_file(&path);
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
                crate::test_support::remove_temp_file(&path);
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
        assert!(error.contains("Keine Verbindung"));
        assert!(started.elapsed() < Duration::from_secs(5));
        server.join().unwrap();
        crate::test_support::remove_temp_file(&path);
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
        crate::test_support::remove_temp_file(&path);
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
        assert!(error.contains("nicht erreichbar"));
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
