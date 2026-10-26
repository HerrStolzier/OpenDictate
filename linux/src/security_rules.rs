//! Linux behavior checked against `fixtures/security/rules.json`.

use crate::insert::{paste_into, Skip};
use crate::policy;
use crate::server::Server;
use crate::settings::Settings;
use crate::test_http::serve;
use crate::transcribe::Transcriber;
use crate::translate::Translator;
use crate::window::TargetWindow;

fn rules() -> serde_json::Value {
    serde_json::from_str(include_str!("../../fixtures/security/rules.json")).unwrap()
}

fn window(class: &str) -> TargetWindow {
    TargetWindow {
        address: "0x5a1b2c".to_string(),
        class: class.to_string(),
    }
}

fn padded(prefix: &str, bytes: usize) -> String {
    assert!(prefix.len() <= bytes);
    let mut body = String::with_capacity(bytes);
    body.push_str(prefix);
    body.extend(std::iter::repeat_n(' ', bytes - prefix.len()));
    body
}

#[test]
fn security_rules_accept_https_and_http_only_for_loopback() {
    for case in rules()["addresses"].as_array().unwrap() {
        let input = case["input"].as_str().unwrap();
        let parsed = Server::parse(input);
        if case["accept"].as_bool().unwrap() {
            let server = parsed.unwrap_or_else(|error| panic!("{input}: {error}"));
            assert_eq!(
                server.base(),
                case["canonical"].as_str().unwrap(),
                "{input}"
            );
            assert_eq!(
                server.sends_api_key(),
                !case["loopback"].as_bool().unwrap(),
                "{input}"
            );
        } else {
            assert!(parsed.is_err(), "{input}");
        }
    }
}

fn response_limits() -> (usize, usize) {
    let rules = rules();
    let limits = &rules["response_limits"];
    let shared = limits["shared_transcription_bytes"].as_u64().unwrap();
    let translation = limits["translation_bytes"].as_u64().unwrap();
    let platforms = &limits["by_platform"];
    for platform in ["linux", "macos", "ios", "windows"] {
        assert_eq!(
            platforms[platform]["transcription"].as_u64().unwrap(),
            shared,
            "{platform}"
        );
        assert_eq!(
            platforms[platform]["translation"].as_u64().unwrap(),
            translation,
            "{platform}"
        );
    }
    assert!(limits["windows_transcription_exception"]
        .as_str()
        .unwrap()
        .contains("128"));
    (
        usize::try_from(platforms["linux"]["transcription"].as_u64().unwrap()).unwrap(),
        usize::try_from(platforms["linux"]["translation"].as_u64().unwrap()).unwrap(),
    )
}

#[test]
fn security_rules_cap_transcription_responses() {
    let (limit, _) = response_limits();
    assert_eq!(
        transcribe_body(&padded(r#"{"text":"ok"}"#, limit)).unwrap(),
        "ok"
    );
    assert!(transcribe_body(&padded(r#"{"text":"ok"}"#, limit + 1)).is_err());
}

#[test]
fn security_rules_cap_translation_responses() {
    let (_, limit) = response_limits();
    let prefix = r#"{"choices":[{"message":{"content":"ok"}}]}"#;
    assert_eq!(translate_body(&padded(prefix, limit)).unwrap().text, "ok");
    assert!(translate_body(&padded(prefix, limit + 1)).is_err());
}

fn transcribe_body(body: &str) -> Result<String, crate::server::Failure> {
    let (endpoint, stub) = serve("200 OK", body);
    let server = Server::parse(&format!("{endpoint}/v1")).unwrap();
    let result =
        Transcriber::new(&server).transcribe_bytes(b"RIFF-test-audio", None, &Settings::default());
    stub.join().unwrap();
    result
}

fn translate_body(
    body: &str,
) -> Result<crate::translate::TranslationResult, crate::server::Failure> {
    let (endpoint, stub) = serve("200 OK", body);
    let server = Server::parse(&format!("{endpoint}/v1")).unwrap();
    let result = Translator::new(&server).translate("Hallo", "en", "local", None);
    stub.join().unwrap();
    result
}

#[test]
fn security_rules_block_terminal_auto_paste_on_line_breaks() {
    let rules = rules();
    let paste = &rules["auto_paste"];
    let breaks: Vec<char> = paste["line_breaks"]
        .as_array()
        .unwrap()
        .iter()
        .map(|value| {
            let text = value.as_str().unwrap();
            let mut chars = text.chars();
            let character = chars.next().unwrap();
            assert!(chars.next().is_none(), "{text:?}");
            character
        })
        .collect();
    let blocked: Vec<&str> = paste["blocked_in_terminal"]
        .as_array()
        .unwrap()
        .iter()
        .map(|value| value.as_str().unwrap())
        .collect();
    for character in &breaks {
        assert!(
            blocked.iter().any(|sample| sample.contains(*character)),
            "no blocked sample contains {character:?}"
        );
        assert_blocked(&format!("echo hi{character}rm -rf /"));
    }
    for sample in &blocked {
        assert!(
            breaks.iter().any(|character| sample.contains(*character)),
            "{sample:?}"
        );
        assert_blocked(sample);
    }
    for case in paste["allowed"].as_array().unwrap() {
        let text = case["text"].as_str().unwrap();
        let class = if case["terminal"].as_bool().unwrap() {
            "Alacritty"
        } else {
            "chromium"
        };
        let delivered = policy::text_for_delivery(text);
        assert_ne!(
            paste_into(&window(class), &delivered),
            Err(Skip::MultilineIntoTerminal),
            "{text:?}"
        );
    }

    let nel = blocked
        .iter()
        .copied()
        .find(|sample| sample.contains('\u{0085}'))
        .unwrap();
    let (endpoint, stub) = serve("200 OK", &serde_json::json!({"text": nel}).to_string());
    let server = Server::parse(&format!("{endpoint}/v1")).unwrap();
    let transcript =
        Transcriber::new(&server).transcribe_bytes(b"RIFF-test-audio", None, &Settings::default());
    stub.join().unwrap();
    assert_blocked(&transcript.unwrap());
    let (endpoint, stub) = serve(
        "200 OK",
        &serde_json::json!({"choices":[{"message":{"content": nel}}]}).to_string(),
    );
    let server = Server::parse(&format!("{endpoint}/v1")).unwrap();
    let translation = Translator::new(&server)
        .translate("Hallo", "en", "local", None)
        .unwrap();
    stub.join().unwrap();
    assert_blocked(&translation.text);
}

fn assert_blocked(sample: &str) {
    let delivered = policy::text_for_delivery(sample);
    assert!(policy::is_multiline(sample), "{sample:?}");
    assert!(policy::is_multiline(&delivered), "{delivered:?}");
    assert_eq!(
        paste_into(&window("Alacritty"), sample),
        Err(Skip::MultilineIntoTerminal),
        "{sample:?}"
    );
    assert_eq!(
        paste_into(&window("Alacritty"), &delivered),
        Err(Skip::MultilineIntoTerminal),
        "{delivered:?}"
    );
}
