//! Where transcription and translation go: OpenAI, or a custom server
//! ("Eigener Server") that speaks the same API, e.g. whisper.cpp or another
//! local model. The address is the base URL including `/v1`; the request
//! paths are appended to it.

pub const OPENAI_BASE: &str = "https://api.openai.com/v1";
pub const BASE_URL_ENV: &str = "OPENAI_BASE_URL";
const MAX_ADDRESS_CHARS: usize = 512;

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

pub fn custom_network_failure(server: &Server) -> Failure {
    Failure { custom_network: true, message: crate::tr!(
        "Dein Server ({}) ist nicht erreichbar oder zu langsam. Prüf, ob er läuft. Mit `opendictate retry --openai` kannst du die gesicherte Aufnahme einmal an OpenAI senden.",
        "Your server ({}) is unreachable or too slow. Check that it is running. `opendictate retry --openai` sends the kept recording to OpenAI once.", server.log_host()) }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Server {
    base: String,
    host: String,
    custom: bool,
    loopback: bool,
}

/// Where the active address came from, for `settings show`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Source {
    Default,
    Settings,
    Environment,
}

impl Server {
    pub fn openai() -> Self {
        Self::parse(OPENAI_BASE).expect("the OpenAI address is valid")
    }

    /// The stored address wins over `OPENAI_BASE_URL`; without either,
    /// OpenAI is used.
    pub fn resolve(stored: Option<&str>) -> Result<(Self, Source), String> {
        let environment = std::env::var(BASE_URL_ENV).ok();
        Self::resolve_from(stored, environment.as_deref())
    }

    fn resolve_from(
        stored: Option<&str>,
        environment: Option<&str>,
    ) -> Result<(Self, Source), String> {
        if let Some(stored) = stored {
            return Ok((Self::parse(stored)?, Source::Settings));
        }
        match environment.map(str::trim).filter(|value| !value.is_empty()) {
            // A broken variable must not silently send audio to OpenAI.
            Some(value) => Self::parse(value)
                .map(|server| (server, Source::Environment))
                .map_err(|error| {
                    crate::tr!(
                        "{BASE_URL_ENV} ist ungültig: {error}",
                        "{BASE_URL_ENV} is invalid: {error}"
                    )
                }),
            None => Ok((Self::openai(), Source::Default)),
        }
    }

    /// Validates a server address and returns it in the form that is
    /// stored: lowercase scheme and host, no trailing slash.
    pub fn parse(address: &str) -> Result<Self, String> {
        let address = address.trim();
        if address.is_empty()
            || address.chars().count() > MAX_ADDRESS_CHARS
            || !address
                .chars()
                .all(|character| character.is_ascii_graphic())
        {
            return Err(invalid());
        }
        // No credentials, query or fragment: the address is shown and
        // logged by host, and a key belongs in the keyring only.
        if address.contains(['@', '?', '#', '\\']) {
            return Err(crate::tr!(
                "Die Server-Adresse darf keine Zugangsdaten, keine Abfrage (?) und keinen Anker (#) enthalten.",
                "The server address must not contain credentials, a query (?) or a fragment (#)."
            ));
        }
        let lower = address.to_ascii_lowercase();
        let (scheme, rest) = if lower.starts_with("https://") {
            ("https", &address["https://".len()..])
        } else if lower.starts_with("http://") {
            ("http", &address["http://".len()..])
        } else {
            return Err(crate::tr!(
                "Die Server-Adresse muss mit https:// beginnen (http:// nur für diesen Rechner).",
                "The server address must start with https:// (http:// only for this computer)."
            ));
        };
        let (authority, path) = rest.split_at(rest.find('/').unwrap_or(rest.len()));
        let (host, port) = split_authority(authority).ok_or_else(invalid)?;
        let host = host.to_ascii_lowercase();
        if let Some(port) = port {
            if !matches!(port.parse::<u16>(), Ok(number) if number > 0) {
                return Err(invalid());
            }
        }
        let loopback = matches!(host.as_str(), "localhost" | "127.0.0.1" | "[::1]");
        if scheme == "http" && !loopback {
            return Err(crate::tr!(
                "http:// geht nur für diesen Rechner (localhost, 127.0.0.1, [::1]); nimm sonst https://.",
                "http:// only works for this computer (localhost, 127.0.0.1, [::1]); use https:// otherwise."
            ));
        }
        let path = path.trim_end_matches('/');
        let base = match port {
            Some(port) => format!("{scheme}://{host}:{port}{path}"),
            None => format!("{scheme}://{host}{path}"),
        };
        let custom = base != OPENAI_BASE;
        Ok(Self {
            base,
            host,
            custom,
            loopback,
        })
    }

    pub fn base(&self) -> &str {
        &self.base
    }

    pub fn transcription_url(&self) -> String {
        format!("{}/audio/transcriptions", self.base)
    }

    pub fn chat_url(&self) -> String {
        format!("{}/chat/completions", self.base)
    }

    pub fn is_custom(&self) -> bool {
        self.custom
    }

    /// Requests to this computer carry no API key; every other server gets
    /// the stored key.
    pub fn sends_api_key(&self) -> bool {
        !self.loopback
    }

    /// Whether the path is empty, so the usual `/v1` is probably missing.
    pub fn lacks_path(&self) -> bool {
        self.base.matches('/').count() == 2
    }

    /// The host only, without path or port, for the operations log.
    pub fn log_host(&self) -> &str {
        &self.host
    }
}

/// Splits `host[:port]` and `[v6]:port`; rejects anything else.
fn split_authority(authority: &str) -> Option<(&str, Option<&str>)> {
    let (host, port) = if authority.starts_with('[') {
        let end = authority.find(']')?;
        let (host, rest) = authority.split_at(end + 1);
        let inner = &host[1..host.len() - 1];
        if inner.is_empty()
            || !inner
                .chars()
                .all(|character| character.is_ascii_hexdigit() || matches!(character, ':' | '.'))
        {
            return None;
        }
        match rest {
            "" => (host, None),
            _ => (host, Some(rest.strip_prefix(':')?)),
        }
    } else {
        let (host, port) = match authority.split_once(':') {
            Some((host, port)) => (host, Some(port)),
            None => (authority, None),
        };
        let valid = !host.is_empty()
            && !host.starts_with(['-', '.'])
            && host.chars().all(|character| {
                character.is_ascii_alphanumeric() || matches!(character, '-' | '.')
            });
        if !valid {
            return None;
        }
        (host, port)
    };
    if port.is_some_and(|port| port.is_empty() || !port.chars().all(|c| c.is_ascii_digit())) {
        return None;
    }
    Some((host, port))
}

fn invalid() -> String {
    crate::tr!(
        "Ungültige Server-Adresse. Nimm z. B. http://127.0.0.1:8080/v1.",
        "Invalid server address; use e.g. http://127.0.0.1:8080/v1."
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn base(address: &str) -> String {
        Server::parse(address).unwrap().base().to_string()
    }

    #[test]
    fn openai_is_the_default_and_not_custom() {
        let (server, source) = Server::resolve_from(None, None).unwrap();
        assert_eq!(source, Source::Default);
        assert!(!server.is_custom());
        assert!(server.sends_api_key());
        assert_eq!(
            server.transcription_url(),
            "https://api.openai.com/v1/audio/transcriptions"
        );
        assert_eq!(
            server.chat_url(),
            "https://api.openai.com/v1/chat/completions"
        );
        assert!(!Server::parse("HTTPS://API.OpenAI.com/v1/")
            .unwrap()
            .is_custom());
    }

    #[test]
    fn addresses_are_normalized() {
        assert_eq!(
            base("http://LOCALHOST:8080/v1/"),
            "http://localhost:8080/v1"
        );
        assert_eq!(
            base("  https://api.groq.com/openai/v1 "),
            "https://api.groq.com/openai/v1"
        );
        assert_eq!(base("http://[::1]:9000/v1"), "http://[::1]:9000/v1");
        assert_eq!(base("http://127.0.0.1"), "http://127.0.0.1");
    }

    #[test]
    fn plain_http_is_only_allowed_for_this_computer() {
        for address in [
            "http://localhost/v1",
            "http://127.0.0.1:8080/v1",
            "http://[::1]/v1",
        ] {
            assert!(Server::parse(address).is_ok(), "{address}");
        }
        for address in [
            "http://192.168.1.20:8080/v1",
            "http://example.com/v1",
            "http://127.0.0.2/v1",
            "http://localhost.example.com/v1",
        ] {
            assert!(
                Server::parse(address).unwrap_err().contains("http://"),
                "{address}"
            );
        }
    }

    #[test]
    fn credentials_query_fragment_and_odd_input_are_rejected() {
        for address in [
            "https://user:secret@example.com/v1",
            "https://example.com/v1?key=secret",
            "https://example.com/v1#part",
            "ftp://example.com/v1",
            "example.com/v1",
            "https://",
            "https://exa mple.com/v1",
            "https://example.com:0/v1",
            "https://example.com:99999/v1",
            "https://example.com:/v1",
            "https://[nope]/v1",
            "https://-example.com/v1",
            "https://exämple.com/v1",
            "",
        ] {
            assert!(Server::parse(address).is_err(), "{address}");
        }
        assert!(Server::parse(&format!("https://example.com/{}", "a".repeat(600))).is_err());
    }

    #[test]
    fn only_loopback_addresses_go_without_a_key() {
        assert!(!Server::parse("http://localhost:8080/v1")
            .unwrap()
            .sends_api_key());
        assert!(!Server::parse("https://127.0.0.1/v1")
            .unwrap()
            .sends_api_key());
        assert!(Server::parse("https://api.groq.com/openai/v1")
            .unwrap()
            .sends_api_key());
    }

    #[test]
    fn stored_address_wins_over_the_environment() {
        let (server, source) = Server::resolve_from(
            Some("http://localhost:8080/v1"),
            Some("https://other.example/v1"),
        )
        .unwrap();
        assert_eq!(source, Source::Settings);
        assert_eq!(server.base(), "http://localhost:8080/v1");
        let (server, source) =
            Server::resolve_from(None, Some("https://other.example/v1")).unwrap();
        assert_eq!(source, Source::Environment);
        assert_eq!(server.base(), "https://other.example/v1");
        let (_, source) = Server::resolve_from(None, Some("  ")).unwrap();
        assert_eq!(source, Source::Default);
    }

    #[test]
    fn a_broken_environment_variable_is_an_error() {
        let error = Server::resolve_from(None, Some("http://192.168.1.5/v1")).unwrap_err();
        assert!(error.contains(BASE_URL_ENV));
    }

    #[test]
    fn the_log_sees_only_the_host() {
        let server = Server::parse("https://models.example.com:8443/private/v1").unwrap();
        assert_eq!(server.log_host(), "models.example.com");
        assert!(Server::parse("http://localhost:8080").unwrap().lacks_path());
        assert!(!Server::parse("http://localhost:8080/v1")
            .unwrap()
            .lacks_path());
    }
}
