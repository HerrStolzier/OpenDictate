use std::io::Read;
use std::path::Path;
use std::time::Duration;

use serde::Deserialize;

use crate::settings::{validate_model, Settings};

const DEFAULT_ENDPOINT: &str = "https://api.openai.com/v1/audio/transcriptions";
const MAX_UPLOAD_BYTES: usize = 25 * 1_024 * 1_024;

pub struct Transcriber {
    endpoint: String,
    agent: ureq::Agent,
}

impl Transcriber {
    pub fn new() -> Self {
        Self::with_endpoint(DEFAULT_ENDPOINT)
    }

    fn with_endpoint(endpoint: &str) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(30))
            .timeout_read(Duration::from_secs(120))
            .timeout_write(Duration::from_secs(30))
            .redirects(0)
            .build();
        Self {
            endpoint: endpoint.to_string(),
            agent,
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
            return Err("API-Schlüssel fehlt.".to_string());
        }
        let audio = std::fs::read(audio_path).map_err(|_| "Aufnahme nicht lesbar.".to_string())?;
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
            return Err("API-Schlüssel fehlt.".to_string());
        }
        if audio.is_empty() || audio.len() > MAX_UPLOAD_BYTES {
            return Err("Aufnahme hat eine ungültige Größe.".to_string());
        }
        let boundary = format!("OpenDictateBoundary{}", std::process::id());
        let body = multipart_body(&boundary, audio, settings);
        let response = self
            .agent
            .post(&self.endpoint)
            .set("Authorization", &format!("Bearer {api_key}"))
            .set(
                "Content-Type",
                &format!("multipart/form-data; boundary={boundary}"),
            )
            .send_bytes(&body);
        decode_response(response)
    }
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
                401 => "API-Schlüssel ist ungültig.".to_string(),
                413 => "Aufnahme ist für den Upload zu groß.".to_string(),
                429 => "OpenAI-Limit erreicht. Bitte später erneut versuchen.".to_string(),
                _ => "Transkription fehlgeschlagen.".to_string(),
            });
        }
        Err(ureq::Error::Transport(_)) => {
            return Err("Netzwerkfehler bei der Transkription.".to_string())
        }
    };
    let mut data = Vec::new();
    response
        .into_reader()
        .take(1_024 * 1_024)
        .read_to_end(&mut data)
        .map_err(|_| "Ungültige Antwort von OpenAI.".to_string())?;
    #[derive(Deserialize)]
    struct Response {
        text: String,
    }
    let parsed: Response =
        serde_json::from_slice(&data).map_err(|_| "Ungültige Antwort von OpenAI.".to_string())?;
    Ok(parsed.text.trim().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::thread;

    fn serve(status: &str, body: &str) -> (String, thread::JoinHandle<Vec<u8>>) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let status = status.to_string();
        let body = body.to_string();
        let handle = thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut request = Vec::new();
            let mut chunk = [0u8; 4096];
            loop {
                let count = stream.read(&mut chunk).unwrap();
                if count == 0 {
                    break;
                }
                request.extend_from_slice(&chunk[..count]);
                if let Some(length) = content_length(&request) {
                    if request
                        .windows(4)
                        .position(|part| part == b"\r\n\r\n")
                        .is_some_and(|header_end| request.len() >= header_end + 4 + length)
                    {
                        break;
                    }
                }
            }
            write!(
                stream,
                "HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            )
            .unwrap();
            request
        });
        (format!("http://{address}"), handle)
    }

    fn content_length(request: &[u8]) -> Option<usize> {
        let text = String::from_utf8_lossy(request);
        text.lines().find_map(|line| {
            line.to_ascii_lowercase()
                .strip_prefix("content-length: ")
                .and_then(|value| value.trim().parse().ok())
        })
    }

    fn audio_file() -> std::path::PathBuf {
        let path =
            std::env::temp_dir().join(format!("opendictate-http-{}.wav", std::process::id()));
        std::fs::write(&path, b"RIFF-test-audio").unwrap();
        path
    }

    #[test]
    fn stub_receives_multipart_and_returns_trimmed_text() {
        let (endpoint, server) = serve("200 OK", r#"{"text":"  Hallo Linux.  "}"#);
        let path = audio_file();
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
        let path = audio_file();
        let error = Transcriber::with_endpoint(&endpoint)
            .transcribe(&path, "test-key", &Settings::default())
            .unwrap_err();
        assert!(error.contains("ungültig"));
        assert!(!error.contains("private"));
        server.join().unwrap();
        let _ = std::fs::remove_file(path);
    }
}
