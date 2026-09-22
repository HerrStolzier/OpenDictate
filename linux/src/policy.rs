pub fn can_delete_audio(transcript: &str, clipboard_copied: bool) -> bool {
    !transcript.trim().is_empty() && clipboard_copied
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_a_nonempty_clipboard_delivery_allows_deletion() {
        assert!(can_delete_audio("Text", true));
        assert!(!can_delete_audio("", true));
        assert!(!can_delete_audio("   ", true));
        assert!(!can_delete_audio("Text", false));
    }
}
