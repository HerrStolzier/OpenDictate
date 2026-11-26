pub fn can_delete_audio(transcript: &str, clipboard_copied: bool) -> bool {
    !transcript.trim().is_empty() && clipboard_copied
}

/// Text from the server as it may reach the clipboard: line endings become
/// `\n`, control characters other than tab and newline and the invisible
/// bidirectional controls are dropped, surrounding whitespace is trimmed.
/// A server or model cannot smuggle an escape sequence or a hidden
/// direction switch into the pasted text.
pub fn sanitize_transcript(text: &str) -> String {
    let normalized = text
        .replace("\r\n", "\n")
        .replace(['\r', '\u{2028}', '\u{2029}'], "\n");
    let cleaned: String = normalized
        .chars()
        .filter(|&c| !(c.is_control() && c != '\n' && c != '\t') && !is_bidi_control(c))
        .collect();
    cleaned.trim().to_string()
}

/// True for text that spans more than one line after sanitizing.
pub fn is_multiline(text: &str) -> bool {
    text.chars()
        .any(|c| matches!(c, '\n' | '\r' | '\u{2028}' | '\u{2029}'))
}

fn is_bidi_control(c: char) -> bool {
    matches!(c, '\u{202A}'..='\u{202E}' | '\u{2066}'..='\u{2069}' | '\u{200E}' | '\u{200F}' | '\u{061C}')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shared_text_fixtures() {
        let cases: serde_json::Value =
            serde_json::from_str(include_str!("../../fixtures/text/sanitize.json")).unwrap();
        for case in cases.as_array().unwrap() {
            let actual = sanitize_transcript(case["input"].as_str().unwrap());
            assert_eq!(
                actual,
                case["expected"].as_str().unwrap(),
                "{}",
                case["name"]
            );
            assert_eq!(
                is_multiline(&actual),
                case["multiline"].as_bool().unwrap(),
                "{}",
                case["name"]
            );
        }
    }

    #[test]
    fn only_a_nonempty_clipboard_delivery_allows_deletion() {
        assert!(can_delete_audio("Text", true));
        assert!(!can_delete_audio("", true));
        assert!(!can_delete_audio("   ", true));
        assert!(!can_delete_audio("Text", false));
    }

    #[test]
    fn sanitizing_drops_controls_and_keeps_line_breaks() {
        assert_eq!(sanitize_transcript("  Hallo\r\nWelt\r"), "Hallo\nWelt");
        assert_eq!(
            sanitize_transcript("eins\u{2028}zwei\u{2029}drei"),
            "eins\nzwei\ndrei"
        );
        assert_eq!(sanitize_transcript("a\u{1b}b\u{7}c\u{0}\u{85}d"), "abcd");
        assert_eq!(sanitize_transcript("tab\there"), "tab\there");
        assert_eq!(sanitize_transcript("x\u{202E}y\u{2066}z\u{200F}"), "xyz");
        assert_eq!(sanitize_transcript("Grüße 🧪"), "Grüße 🧪");
        assert!(is_multiline("eins\nzwei"));
        assert!(is_multiline("eins\u{2028}zwei"));
        assert!(!is_multiline("eine Zeile"));
    }
}
