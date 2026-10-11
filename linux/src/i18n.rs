//! User-facing text follows the system language: German when the locale
//! starts with `de`, English otherwise.

#[cfg(not(test))]
use std::sync::OnceLock;

/// Picks German for the first set variable among LC_ALL, LC_MESSAGES and
/// LANG (the POSIX order) when it starts with `de`.
pub fn pick(vars: [Option<&str>; 3]) -> bool {
    vars.into_iter()
        .flatten()
        .find(|value| !value.is_empty())
        .is_some_and(|value| value.starts_with("de"))
}

#[cfg(not(test))]
pub fn is_german() -> bool {
    static GERMAN: OnceLock<bool> = OnceLock::new();
    *GERMAN.get_or_init(|| {
        let read = |name| std::env::var(name).ok();
        let (all, messages, lang) = (read("LC_ALL"), read("LC_MESSAGES"), read("LANG"));
        pick([all.as_deref(), messages.as_deref(), lang.as_deref()])
    })
}

/// Tests keep asserting the German texts, independent of the machine's locale.
#[cfg(test)]
pub fn is_german() -> bool {
    true
}

/// Chooses between a German and an English static text.
pub fn t(de: &'static str, en: &'static str) -> &'static str {
    if is_german() {
        de
    } else {
        en
    }
}

/// Formats the German or the English template with the same arguments.
#[macro_export]
macro_rules! tr {
    ($de:literal, $en:literal $(, $arg:expr)* $(,)?) => {
        if $crate::i18n::is_german() {
            format!($de $(, $arg)*)
        } else {
            format!($en $(, $arg)*)
        }
    };
}

#[cfg(test)]
mod tests {
    use super::pick;

    #[test]
    fn german_locale_picks_german() {
        assert!(pick([None, None, Some("de_DE.UTF-8")]));
        assert!(pick([Some("de_AT.UTF-8"), None, Some("en_US.UTF-8")]));
    }

    #[test]
    fn first_set_variable_wins() {
        assert!(!pick([Some("en_US.UTF-8"), None, Some("de_DE.UTF-8")]));
        assert!(!pick([None, Some("C"), Some("de_DE.UTF-8")]));
        assert!(pick([Some(""), None, Some("de_DE.UTF-8")]));
    }

    #[test]
    fn missing_or_other_locale_picks_english() {
        assert!(!pick([None, None, None]));
        assert!(!pick([None, None, Some("C.UTF-8")]));
        assert!(!pick([None, None, Some("fr_FR.UTF-8")]));
    }
}
