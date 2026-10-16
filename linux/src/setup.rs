//! `opendictate setup`: one guided run through what a new install needs,
//! the service (OpenAI key or custom server) and the start shortcut.

use std::io::{self, BufRead, IsTerminal, Read, Write};
use std::time::{Duration, Instant};

use crate::i18n::t;
use crate::server::Server;
use crate::settings::{self, Settings};
use crate::shortcut::{self, Availability, Choice};
use crate::{keyring, path_error, paths, tr};

pub fn run() -> Result<(), String> {
    if !io::stdin().is_terminal() || !io::stdout().is_terminal() {
        return Err(tr!(
            "`opendictate setup` braucht ein Terminal; einzeln geht es mit `opendictate settings …` und `opendictate shortcut set …`.",
            "`opendictate setup` needs a terminal; step by step it works with `opendictate settings …` and `opendictate shortcut set …`."
        ));
    }
    // Fails early with a clear message when no keyring is running.
    keyring::status()?;
    println!("{}\n", t("OpenDictate einrichten", "Set up OpenDictate"));
    service_step()?;
    println!();
    keyring::ensure_recording_auth()?;
    let mode = recording_mode()?;
    let choice = shortcut_step(mode)?;
    println!();
    match choice {
        Some(choice) if mode == settings::ShortcutMode::Hold => println!("{}", tr!("Fertig. Halte {} zum Sprechen, lass zum Beenden los.", "Done. Hold {} while speaking, release to stop.", choice.label())),
        Some(choice) => println!(
            "{}",
            tr!(
                "Fertig. Klick in ein Textfeld, drück {0}, sprich, drück {0} nochmal.",
                "Done. Click into a text field, press {0}, speak, press {0} again.",
                choice.label()
            )
        ),
        None => println!(
            "{}",
            t(
                "Fertig. Mit deinem Kürzel für `opendictate toggle` startest und stoppst du ein Diktat.",
                "Done. Your shortcut for `opendictate toggle` starts and stops a dictation."
            )
        ),
    }
    println!(
        "{}",
        t(
            "Übersetzen, Sprache und mehr: `opendictate help`.",
            "Translation, language and more: `opendictate help`."
        )
    );
    Ok(())
}

fn service_step() -> Result<(), String> {
    let path = paths::settings_path().map_err(path_error)?;
    let settings = Settings::load(&path)?;
    let (server, _) = settings.resolve_server()?;
    println!(
        "{}",
        t(
            "1/2 Wer schreibt deine Aufnahme ab?",
            "1/2 Who turns your recording into text?"
        )
    );
    println!(
        "  1) {}",
        t(
            "OpenAI mit deinem API-Schlüssel (empfohlen)",
            "OpenAI with your API key (recommended)"
        )
    );
    println!(
        "  2) {}",
        t(
            "Eigener Server, z. B. ein Modell auf diesem Rechner",
            "Custom server, e.g. a model on this computer"
        )
    );
    let default = if server.is_custom() { 2 } else { 1 };
    if ask_number(2, default)? == 1 {
        crate::settings_server_off()?;
        let (server, _) = Server::resolve(None)?;
        ensure_key(&server)
    } else {
        custom_server(&path)
    }
}

fn custom_server(path: &std::path::Path) -> Result<(), String> {
    let mut settings = Settings::load(path)?;
    let current = settings.server.clone();
    let server = loop {
        let prompt = match &current {
            Some(current) => tr!(
                "Server-Adresse [{current}]: ",
                "Server address [{current}]: "
            ),
            None => tr!(
                "Server-Adresse (z. B. http://127.0.0.1:8080/v1): ",
                "Server address (e.g. http://127.0.0.1:8080/v1): "
            ),
        };
        let answer = ask(&prompt)?;
        let address = match (answer.is_empty(), &current) {
            (true, Some(current)) => current.clone(),
            (true, None) => continue,
            (false, _) => answer,
        };
        match Server::parse(&address) {
            Ok(server) if server.is_custom() => break server,
            Ok(_) => {
                println!(
                    "{}",
                    t(
                        "Das ist OpenAI; dafür oben 1 wählen.",
                        "That is OpenAI; pick 1 above for it."
                    )
                );
                return service_step();
            }
            Err(error) => println!("{error}"),
        }
    };
    if server.lacks_path() {
        println!(
            "{}",
            t(
                "Hinweis: Die meisten Server erwarten die Adresse mit /v1 am Ende.",
                "Note: most servers expect the address to end in /v1."
            )
        );
    }
    settings.custom_model = ask_model(
        t(
            "Modellname für die Abschrift",
            "Model name for transcription",
        ),
        &settings.custom_model,
    )?;
    if settings.target_language.is_some() {
        settings.custom_translation_model = ask_model(
            t(
                "Modellname für die Übersetzung",
                "Model name for translation",
            ),
            &settings.custom_translation_model,
        )?;
    }
    // Saved together, so a cancelled setup never leaves the new server with
    // OpenAI's model names.
    settings.server = Some(server.base().to_string());
    settings.service = Some(crate::settings::Service::Custom);
    settings.save(path)?;
    if server.sends_api_key() {
        println!(
            "{}",
            t(
                "Dein API-Schlüssel wird an diesen Server gesendet.",
                "Your API key is sent to this server."
            )
        );
        ensure_key(&server)
    } else {
        println!(
            "{}",
            t(
                "An Adressen auf diesem Rechner sendet OpenDictate keinen API-Schlüssel.",
                "OpenDictate sends no API key to addresses on this computer."
            )
        );
        report_check(&server, check(&server, None));
        Ok(())
    }
}

fn ask_model(label: &str, current: &str) -> Result<String, String> {
    loop {
        let answer = ask(&format!("{label} [{current}]: "))?;
        if answer.is_empty() {
            return Ok(current.to_string());
        }
        match settings::validate_model_name(&answer) {
            Ok(()) => return Ok(answer),
            Err(error) => println!("{error}"),
        }
    }
}

/// Makes sure a working key is stored; asks for one (hidden) when it is
/// missing, rejected, or the user wants to replace it.
fn ensure_key(server: &Server) -> Result<(), String> {
    if !server.sends_api_key() {
        // Only reachable through OPENAI_BASE_URL pointing at this computer.
        report_check(server, check(server, None));
        return Ok(());
    }
    let (present, _) = keyring::status()?;
    // A stored key that may still work is only replaced by one that is
    // confirmed to work.
    let mut keep_stored = present;
    if present {
        let replace = ask_yes(
            t(
                "Ein API-Schlüssel ist schon gespeichert. Durch einen neuen ersetzen?",
                "An API key is already stored. Replace it?",
            ),
            false,
        )?;
        if !replace {
            let key = keyring::api_key()?;
            if report_check(server, check(server, Some(&key))) != Check::KeyRejected {
                return Ok(());
            }
            keep_stored = false;
        }
    }
    loop {
        let key = read_hidden(t(
            "API-Schlüssel einfügen (bleibt unsichtbar), dann Enter: ",
            "Paste the API key (stays hidden), then Enter: ",
        ))?;
        if key.is_empty() {
            continue;
        }
        // Checked before storing, so a rejected key never replaces a
        // working one.
        let result = check(server, Some(&key));
        if result == Check::KeyRejected {
            report_check(server, result);
            continue;
        }
        if keep_stored && result != Check::Works {
            let reason = match (result, server.is_custom()) {
                (Check::Unreachable, false) => t(
                    "OpenAI ist gerade nicht erreichbar",
                    "OpenAI is not reachable right now",
                ),
                (Check::Unreachable, true) => t(
                    "Der Server antwortet nicht (läuft er?)",
                    "The server does not answer (is it running?)",
                ),
                _ => t(
                    "Die Prüfung brachte keine klare Antwort",
                    "The check gave no clear answer",
                ),
            };
            println!(
                "{}",
                tr!(
                    "{reason}; der bisherige Schlüssel bleibt gespeichert. Führ `opendictate setup` später nochmal aus.",
                    "{reason}; the stored key stays. Run `opendictate setup` again later."
                )
            );
            return Ok(());
        }
        if let Err(error) = keyring::store_api_key(&key) {
            println!("{error}");
            continue;
        }
        println!("{}", t("API-Schlüssel gespeichert.", "API key saved."));
        report_check(server, result);
        return Ok(());
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Check {
    Works,
    KeyRejected,
    /// A server on this computer that wants a login, which it never gets.
    LoginRequired,
    Unreachable,
    Unclear,
}

/// Asks the server for its model list: cheap, free at OpenAI, and the key
/// check that a dictation would otherwise do first.
fn check(server: &Server, api_key: Option<&str>) -> Check {
    let agent = ureq::AgentBuilder::new()
        .timeout_connect(Duration::from_secs(5))
        .timeout(Duration::from_secs(10))
        .redirects(0)
        .build();
    let mut request = agent.get(&format!("{}/models", server.base()));
    if let (true, Some(api_key)) = (server.sends_api_key(), api_key) {
        request = request.set("Authorization", &format!("Bearer {api_key}"));
    }
    match request.call() {
        Ok(_) => Check::Works,
        Err(ureq::Error::Status(401 | 403, _)) if server.sends_api_key() => Check::KeyRejected,
        Err(ureq::Error::Status(401 | 403, _)) => Check::LoginRequired,
        // Servers like whisper.cpp have no model list but do answer.
        Err(ureq::Error::Status(_, _)) if server.is_custom() => Check::Works,
        Err(ureq::Error::Status(_, _)) => Check::Unclear,
        Err(ureq::Error::Transport(_)) => Check::Unreachable,
    }
}

fn report_check(server: &Server, result: Check) -> Check {
    let message = match (result, server.is_custom()) {
        (Check::Works, false) => t(
            "Verbindung zu OpenAI klappt, der Schlüssel gilt.",
            "Connection to OpenAI works, the key is valid.",
        ),
        (Check::Works, true) => t("Der Server antwortet.", "The server answers."),
        (Check::LoginRequired, _) => t(
            "Dein lokaler Server will eine Anmeldung. OpenDictate schickt an Server auf diesem Rechner keinen Schlüssel – schalte die Anmeldung dort ab.",
            "Your local server asks for a login. OpenDictate sends no key to servers on this computer – turn the login off there.",
        ),
        (Check::KeyRejected, _) => t(
            "Der Schlüssel wird abgelehnt. Füg einen gültigen Schlüssel ein.",
            "The key is rejected. Paste a valid key.",
        ),
        (Check::Unreachable, false) => t(
            "OpenAI ist gerade nicht erreichbar; der Schlüssel bleibt gespeichert.",
            "OpenAI is not reachable right now; the key stays stored.",
        ),
        (Check::Unreachable, true) => t(
            "Der Server antwortet nicht. Läuft er? Die Adresse bleibt gespeichert.",
            "The server does not answer. Is it running? The address stays stored.",
        ),
        (Check::Unclear, _) => t(
            "Die Verbindung ließ sich nicht prüfen; der Schlüssel bleibt gespeichert.",
            "The connection could not be checked; the key stays stored.",
        ),
    };
    println!("{message}");
    result
}

fn recording_mode() -> Result<settings::ShortcutMode, String> {
    let current = Settings::load(&paths::settings_path().map_err(path_error)?)?.shortcut_mode;
    let default = if current == settings::ShortcutMode::Tap {
        1
    } else {
        2
    };
    println!(
        "{}",
        t(
            "So nimmst du auf: 1) Antippen  2) Gedrückt halten",
            "How to record: 1) Tap  2) Hold"
        )
    );
    let selected = ask_number(2, default)?;
    Ok(if selected == 1 {
        settings::ShortcutMode::Tap
    } else {
        settings::ShortcutMode::Hold
    })
}

fn save_recording_mode(
    mode: settings::ShortcutMode,
    target: &shortcut::Target,
    installed: &shortcut::Installed,
) -> Result<(), String> {
    let result = (|| {
        let path = paths::settings_path().map_err(path_error)?;
        let mut settings = Settings::load(&path)?;
        settings.shortcut_mode = mode;
        settings.save(&path)
    })();
    if let Err(error) = result {
        shortcut::restore(target, installed)?;
        let _ = shortcut::reload();
        return Err(error);
    }
    Ok(())
}

fn shortcut_step(mode: settings::ShortcutMode) -> Result<Option<Choice>, String> {
    println!(
        "{}",
        t(
            "2/2 Mit welchem Kürzel startest und stoppst du ein Diktat?",
            "2/2 Which shortcut starts and stops a dictation?"
        )
    );
    let binds = shortcut::active_binds();
    let current = shortcut::current(binds.as_deref());
    let right_alt = shortcut::right_alt_suits() == Some(true) || current == Some(Choice::RightAlt);
    let options: Vec<Choice> = Choice::ALL
        .into_iter()
        .filter(|choice| *choice != Choice::RightAlt || right_alt)
        .collect();
    let mut default = None;
    for (index, choice) in options.iter().enumerate() {
        let availability = shortcut::availability(*choice, binds.as_deref());
        let note = match &availability {
            Availability::Free => t("frei", "free").to_string(),
            Availability::OpenDictate => {
                t("dein jetziges Kürzel", "your current shortcut").to_string()
            }
            Availability::Taken(action) => tr!("belegt: {action}", "taken: {action}"),
            Availability::Unknown => String::new(),
        };
        let recommended = if index == 0 {
            t(" (empfohlen)", " (recommended)")
        } else {
            ""
        };
        let note = if note.is_empty() {
            note
        } else {
            format!(" – {note}")
        };
        println!("  {}) {}{recommended}{note}", index + 1, choice.label());
        let preferred = match current {
            Some(current) => current == *choice,
            None => availability == Availability::Free || availability == Availability::Unknown,
        };
        if default.is_none() && preferred {
            default = Some(index + 1);
        }
    }
    let skip = options.len() + 1;
    println!(
        "  {skip}) {}",
        t(
            "Überspringen, ich trage es selbst ein",
            "Skip, I'll add it myself"
        )
    );
    if binds.is_none() {
        println!(
            "{}",
            t(
                "(Hyprland läuft nicht, darum ist nicht geprüft, welche Tasten frei sind.)",
                "(Hyprland is not running, so free keys could not be checked.)"
            )
        );
    }
    loop {
        let answer = ask_number(skip, default.unwrap_or(skip))?;
        if answer == skip {
            if current.is_none() {
                print_manual_line(Choice::SuperD, mode);
            }
            return Ok(current);
        }
        let choice = options[answer - 1];
        if Some(choice) == current {
            println!(
                "{}",
                t(
                    "Das Kürzel bleibt, wie es ist.",
                    "The shortcut stays as it is."
                )
            );
            return Ok(Some(choice));
        }
        if let Availability::Taken(action) = shortcut::availability(choice, binds.as_deref()) {
            let anyway = ask_yes(
                &tr!(
                    "{} ist schon belegt ({action}); Hyprland würde dann beides ausführen. Trotzdem nehmen?",
                    "{} is already taken ({action}); Hyprland would then run both. Use it anyway?",
                    choice.label()
                ),
                false,
            )?;
            if !anyway {
                continue;
            }
        }
        return apply_mode(choice, true, mode).map(Some);
    }
}

/// Writes the bind and reports whether Hyprland picked it up. With
/// `ask_first` the user confirms the file change first.
pub fn apply(choice: Choice, ask_first: bool) -> Result<Choice, String> {
    let settings = Settings::load(&paths::settings_path().map_err(path_error)?)?;
    apply_mode(choice, ask_first, settings.shortcut_mode)
}

fn apply_mode(
    choice: Choice,
    ask_first: bool,
    mode: settings::ShortcutMode,
) -> Result<Choice, String> {
    let hypr_dir = shortcut::hypr_dir().map_err(|error| error.to_string())?;
    let Some(target) = shortcut::detect(&hypr_dir) else {
        println!(
            "{}",
            t(
                "Keine Hyprland-Konfiguration gefunden.",
                "No Hyprland config found."
            )
        );
        print_manual_line(choice, mode);
        return Ok(choice);
    };
    if !target.writable() {
        println!(
            "{}",
            tr!(
                "Trag diese Zeile in {} ein (Hyprland lädt sie beim Speichern):",
                "Add this line to {} (Hyprland loads it when you save):",
                shortcut::display_path(&target.path)
            )
        );
        println!("  {}", choice.lines(target.style, mode));
        return Ok(choice);
    }
    if ask_first {
        let confirmed = ask_yes(
            &tr!(
                "In {} eintragen? Vorher wird eine Sicherung angelegt.",
                "Add it to {}? A backup is made first.",
                shortcut::display_path(&target.path)
            ),
            true,
        )?;
        if !confirmed {
            println!(
                "{}",
                tr!("Trag diese Zeile selbst ein:", "Add this line yourself:")
            );
            println!("  {}", choice.lines(target.style, mode));
            return Ok(choice);
        }
    }
    let running = shortcut::active_binds().is_some();
    let installed = shortcut::install(choice, &target, mode)?;
    println!(
        "{}",
        tr!(
            "{} eingetragen in {}; Sicherung: {}",
            "{} added to {}; backup: {}",
            choice.label(),
            shortcut::display_path(&target.path),
            shortcut::display_path(&installed.backup)
        )
    );
    if installed.replaced > 0 {
        println!(
            "{}",
            t(
                "Das bisherige OpenDictate-Kürzel in dieser Datei ist ersetzt.",
                "The previous OpenDictate shortcut in this file was replaced."
            )
        );
    }
    // Hyprland reloads its config when a file changes; without that
    // (autoreload off) it is asked once. A bind it still does not show is
    // undone, so the previous shortcut keeps working.
    let loaded = match wait_loaded(choice, mode, running, Duration::from_secs(3)) {
        Some(false) if shortcut::reload() => {
            wait_loaded(choice, mode, running, Duration::from_secs(2))
        }
        loaded => loaded,
    };
    match loaded {
        None => {
            save_recording_mode(mode, &target, &installed)?;
            installed.prune_older_backups();
            println!(
                "{}",
                t(
                    "Das Kürzel gilt ab dem nächsten Hyprland-Start.",
                    "The shortcut works from the next Hyprland start."
                )
            )
        }
        Some(true) => {
            save_recording_mode(mode, &target, &installed)?;
            installed.prune_older_backups();
            println!(
                "{}",
                t(
                    "Hyprland kennt das Kürzel jetzt.",
                    "Hyprland knows the shortcut now."
                )
            );
            if shortcut::has_other_opendictate_bind(
                shortcut::active_binds().as_deref(),
                Some(choice),
            ) {
                println!(
                    "{}",
                    t(
                        "Ein weiteres OpenDictate-Kürzel aus einer anderen Datei bleibt bestehen.",
                        "Another OpenDictate shortcut from a different file stays in place."
                    )
                );
            }
        }
        Some(false) => {
            shortcut::restore(&target, &installed).map_err(|error| {
                tr!(
                    "Hyprland hat {} nicht übernommen. {error} Den Grund zeigt `hyprctl configerrors`.",
                    "Hyprland did not take {}. {error} `hyprctl configerrors` shows why.",
                    choice.label()
                )
            })?;
            let restored = if shortcut::reload() {
                t(
                    "das bisherige Kürzel gilt weiter",
                    "the previous shortcut still works",
                )
            } else {
                t(
                    "nach `hyprctl reload` gilt das bisherige Kürzel wieder",
                    "after `hyprctl reload` the previous shortcut works again",
                )
            };
            println!(
                "{}",
                tr!(
                    "Hyprland hat {} nicht übernommen; {} ist wieder wie vorher, {restored}. Den Grund zeigt `hyprctl configerrors`.",
                    "Hyprland did not take {}; {} is back as before, {restored}. `hyprctl configerrors` shows why.",
                    choice.label(),
                    shortcut::display_path(&target.path)
                )
            );
            println!(
                "{}",
                tr!(
                    "Wer die Zeile trotzdem will, trägt sie selbst ein:",
                    "To use it anyway, add this line yourself:"
                )
            );
            println!("  {}", choice.lines(target.style, mode));
            return Err(t("Kürzel nicht geändert.", "Shortcut not changed.").to_string());
        }
    }
    Ok(choice)
}

/// Whether Hyprland shows the bind within `timeout`; `None` when Hyprland
/// was not running before the change. While it was, a failed query is
/// retried and counts as not loaded at the deadline.
fn wait_loaded(
    choice: Choice,
    mode: settings::ShortcutMode,
    running: bool,
    timeout: Duration,
) -> Option<bool> {
    let deadline = Instant::now() + timeout;
    loop {
        match shortcut::active_binds() {
            Some(binds) if shortcut::loaded(choice, &binds, mode) => {
                return Some(true);
            }
            None if !running => return None,
            _ => {}
        }
        if Instant::now() >= deadline {
            return Some(false);
        }
        std::thread::sleep(Duration::from_millis(250));
    }
}

fn print_manual_line(choice: Choice, mode: settings::ShortcutMode) {
    println!(
        "{}",
        t(
            "Beispiel für Omarchy (~/.config/hypr/bindings.lua) und klassische Konfiguration:",
            "Example for Omarchy (~/.config/hypr/bindings.lua) and classic config:"
        )
    );
    println!("  {}", choice.lines(shortcut::Style::OmarchyLua, mode));
    println!("  {}", choice.lines(shortcut::Style::Classic, mode));
}

fn ask(prompt: &str) -> Result<String, String> {
    print!("{prompt}");
    let _ = io::stdout().flush();
    let mut line = String::new();
    let read = io::stdin()
        .lock()
        .read_line(&mut line)
        .map_err(|_| aborted())?;
    if read == 0 {
        return Err(aborted());
    }
    Ok(line.trim().to_string())
}

fn ask_number(max: usize, default: usize) -> Result<usize, String> {
    loop {
        let answer = ask(&tr!("Auswahl [{default}]: ", "Choice [{default}]: "))?;
        if answer.is_empty() {
            return Ok(default);
        }
        match answer.parse::<usize>() {
            Ok(number) if (1..=max).contains(&number) => return Ok(number),
            _ => println!("{}", tr!("Gib 1 bis {max} ein.", "Enter 1 to {max}.")),
        }
    }
}

fn ask_yes(question: &str, default: bool) -> Result<bool, String> {
    let hint = match default {
        true => t("[J/n]", "[Y/n]"),
        false => t("[j/N]", "[y/N]"),
    };
    loop {
        let answer = ask(&format!("{question} {hint} "))?.to_lowercase();
        match parse_yes(&answer, default) {
            Some(answer) => return Ok(answer),
            None => println!("{}", t("Gib j oder n ein.", "Enter y or n.")),
        }
    }
}

/// Accepts German and English answers whatever the system language.
fn parse_yes(answer: &str, default: bool) -> Option<bool> {
    match answer {
        "" => Some(default),
        "j" | "ja" | "y" | "yes" => Some(true),
        "n" | "nein" | "no" => Some(false),
        _ => None,
    }
}

fn aborted() -> String {
    tr!("Einrichtung abgebrochen.", "Setup cancelled.")
}

/// Reads a line without showing it. Ctrl+C arrives as a byte here, so the
/// terminal is always restored before the program ends.
fn read_hidden(prompt: &str) -> Result<String, String> {
    print!("{prompt}");
    let _ = io::stdout().flush();
    let result = {
        let _raw = RawTerminal::enable().map_err(|_| aborted())?;
        let mut input = HiddenInput::default();
        let mut stdin = io::stdin().lock();
        let mut byte = [0u8; 1];
        loop {
            match stdin.read(&mut byte) {
                Ok(1) => match input.feed(byte[0]) {
                    Step::More => {}
                    Step::Done => break Ok(input.into_text()),
                    Step::Abort => break Err(aborted()),
                },
                _ => break Err(aborted()),
            }
        }
    };
    println!();
    result
}

#[derive(Debug, PartialEq, Eq)]
enum Step {
    More,
    Done,
    Abort,
}

/// Line editing for the hidden prompt: Enter ends, Backspace and Ctrl+U
/// edit, Ctrl+C and Ctrl+D cancel, escape sequences (arrow keys) are
/// dropped.
#[derive(Default)]
struct HiddenInput {
    bytes: Vec<u8>,
    escape: Escape,
}

#[derive(Default, PartialEq, Eq)]
enum Escape {
    #[default]
    None,
    Started,
    Sequence,
}

impl HiddenInput {
    fn feed(&mut self, byte: u8) -> Step {
        match self.escape {
            Escape::Started => {
                self.escape = if byte == b'[' || byte == b'O' {
                    Escape::Sequence
                } else {
                    Escape::None
                };
                return Step::More;
            }
            Escape::Sequence => {
                if (0x40..=0x7e).contains(&byte) {
                    self.escape = Escape::None;
                }
                return Step::More;
            }
            Escape::None => {}
        }
        match byte {
            b'\r' | b'\n' => Step::Done,
            0x03 => Step::Abort,
            0x04 if self.bytes.is_empty() => Step::Abort,
            0x7f | 0x08 => {
                self.bytes.pop();
                Step::More
            }
            0x15 => {
                self.bytes.clear();
                Step::More
            }
            0x1b => {
                self.escape = Escape::Started;
                Step::More
            }
            byte if byte < 0x20 => Step::More,
            byte => {
                self.bytes.push(byte);
                Step::More
            }
        }
    }

    fn into_text(self) -> String {
        String::from_utf8_lossy(&self.bytes).trim().to_string()
    }
}

/// Switches the terminal to no-echo, byte-wise input and restores it on
/// drop.
struct RawTerminal {
    original: libc::termios,
}

impl RawTerminal {
    fn enable() -> io::Result<Self> {
        // SAFETY: tcgetattr fills the zeroed struct for stdin; both calls
        // only read and write that struct.
        let mut original: libc::termios = unsafe { std::mem::zeroed() };
        if unsafe { libc::tcgetattr(libc::STDIN_FILENO, &mut original) } != 0 {
            return Err(io::Error::last_os_error());
        }
        let mut raw = original;
        raw.c_lflag &= !(libc::ECHO | libc::ICANON | libc::ISIG);
        raw.c_cc[libc::VMIN] = 1;
        raw.c_cc[libc::VTIME] = 0;
        // SAFETY: sets stdin's attributes from a struct tcgetattr filled.
        if unsafe { libc::tcsetattr(libc::STDIN_FILENO, libc::TCSAFLUSH, &raw) } != 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(Self { original })
    }
}

impl Drop for RawTerminal {
    fn drop(&mut self) {
        // SAFETY: restores the attributes read in `enable`.
        unsafe {
            libc::tcsetattr(libc::STDIN_FILENO, libc::TCSAFLUSH, &self.original);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn type_in(bytes: &[u8]) -> (Step, String) {
        let mut input = HiddenInput::default();
        for byte in bytes {
            match input.feed(*byte) {
                Step::More => {}
                step => return (step, input.into_text()),
            }
        }
        (Step::More, input.into_text())
    }

    #[test]
    fn hidden_input_ends_on_enter_and_edits() {
        assert_eq!(type_in(b"sk-test\r"), (Step::Done, "sk-test".to_string()));
        assert_eq!(
            type_in(b"sk-tesx\x7ft\n"),
            (Step::Done, "sk-test".to_string())
        );
        assert_eq!(
            type_in(b"wrong\x15sk-test\r"),
            (Step::Done, "sk-test".to_string())
        );
        assert_eq!(
            type_in(b"  sk-test \r"),
            (Step::Done, "sk-test".to_string())
        );
    }

    #[test]
    fn hidden_input_drops_arrow_keys_and_controls() {
        assert_eq!(
            type_in(b"sk-\x1b[Dte\x1bOAst\x01\r"),
            (Step::Done, "sk-test".to_string())
        );
    }

    #[test]
    fn hidden_input_cancels_on_ctrl_c_and_on_ctrl_d_when_empty() {
        assert_eq!(type_in(b"sk-te\x03").0, Step::Abort);
        assert_eq!(type_in(b"\x04").0, Step::Abort);
        assert_eq!(
            type_in(b"sk\x04-test\r"),
            (Step::Done, "sk-test".to_string())
        );
    }

    #[test]
    fn yes_and_no_work_in_both_languages() {
        assert_eq!(parse_yes("", true), Some(true));
        assert_eq!(parse_yes("", false), Some(false));
        assert_eq!(parse_yes("ja", false), Some(true));
        assert_eq!(parse_yes("y", false), Some(true));
        assert_eq!(parse_yes("nein", true), Some(false));
        assert_eq!(parse_yes("vielleicht", true), None);
    }

    #[test]
    fn unreachable_server_is_reported_as_such() {
        let local = Server::parse("http://127.0.0.1:9/v1").unwrap();
        assert_eq!(check(&local, None), Check::Unreachable);
    }

    #[test]
    fn a_local_server_without_model_list_counts_as_working() {
        let (endpoint, server) = crate::test_http::serve("404 Not Found", "{}");
        let local = Server::parse(&format!("{endpoint}/v1")).unwrap();
        assert_eq!(check(&local, Some("test-key")), Check::Works);
        let request = server.join().unwrap();
        let request = String::from_utf8_lossy(&request);
        assert!(request.starts_with("GET /v1/models "));
        assert!(!request.contains("test-key"));
    }

    #[test]
    fn a_local_server_that_wants_a_login_is_named_as_such() {
        let (endpoint, server) = crate::test_http::serve("401 Unauthorized", "{}");
        let local = Server::parse(&format!("{endpoint}/v1")).unwrap();
        assert_eq!(check(&local, None), Check::LoginRequired);
        server.join().unwrap();
    }
}
