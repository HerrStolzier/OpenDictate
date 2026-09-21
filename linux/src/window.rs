use std::process::{Command, Stdio};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TargetWindow {
    pub address: String,
    pub class: String,
}

pub fn active_window() -> Option<TargetWindow> {
    let output = Command::new("hyprctl")
        .args(["activewindow", "-j"])
        .stdin(Stdio::null())
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    parse_active_window(&String::from_utf8_lossy(&output.stdout))
}

fn parse_active_window(json: &str) -> Option<TargetWindow> {
    let address = json_string_field(json, "address")?;
    let class = json_string_field(json, "class").unwrap_or_default();
    if address.is_empty() {
        return None;
    }
    Some(TargetWindow { address, class })
}

fn json_string_field(json: &str, field: &str) -> Option<String> {
    let needle = format!("\"{field}\"");
    let rest = json.split(&needle).nth(1)?;
    let rest = rest.trim_start_matches(|c: char| c == ' ' || c == ':');
    let rest = rest.trim_start();
    if !rest.starts_with('"') {
        return None;
    }
    let mut value = String::new();
    let mut escaped = false;
    for character in rest.chars().skip(1) {
        if escaped {
            value.push(character);
            escaped = false;
            continue;
        }
        match character {
            '\\' => escaped = true,
            '"' => break,
            other => value.push(other),
        }
    }
    Some(value)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_skips_title() {
        let json = r#"{
            "address": "0xabc",
            "class": "foot",
            "title": "secret user text"
        }"#;
        let window = parse_active_window(json).unwrap();
        assert_eq!(window.address, "0xabc");
        assert_eq!(window.class, "foot");
    }
}
