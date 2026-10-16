//! Production command dispatch and processing with isolated filesystem, Unix
//! sockets, loopback HTTP and owned command stubs. No desktop/keyring/provider.
use super::*;
use std::ffi::OsString;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::sync::MutexGuard;

struct Fixture {
    root: PathBuf,
    auth: Vec<u8>,
    saved: Vec<(&'static str, Option<OsString>)>,
    _lock: MutexGuard<'static, ()>,
}
impl Fixture {
    fn new() -> Self {
        let lock = test_support::env_lock();
        let root = test_support::unique_temp_dir("cli-flow");
        let bin = root.join("bin");
        fs::create_dir(&bin).unwrap();
        let mut auth = Vec::with_capacity(32);
        File::open("/dev/urandom")
            .unwrap()
            .take(32)
            .read_to_end(&mut auth)
            .unwrap();
        assert_eq!(auth.len(), 32);
        let mut fixture = Self {
            root,
            auth,
            saved: Vec::new(),
            _lock: lock,
        };
        for (name, value) in [
            (
                "XDG_CONFIG_HOME",
                Some(fixture.root.join("config").into_os_string()),
            ),
            (
                "XDG_STATE_HOME",
                Some(fixture.root.join("data").into_os_string()),
            ),
            (
                "XDG_RUNTIME_DIR",
                Some(fixture.root.join("runtime").into_os_string()),
            ),
            ("WAYLAND_DISPLAY", Some(OsString::from("fixture"))),
            ("PATH", Some(bin.into_os_string())),
            (server::BASE_URL_ENV, None),
        ] {
            fixture.saved.push((name, std::env::var_os(name)));
            match value {
                Some(value) => std::env::set_var(name, value),
                None => std::env::remove_var(name),
            }
        }
        fixture.auth_available();
        fixture.command("notify-send", "exit 0");
        fixture.command("wl-copy", "/bin/cat >/dev/null");
        fixture
    }
    fn auth_available(&self) {
        self.command(
            "secret-tool",
            &format!(
                "[ \"$1\" = lookup ] && [ \"$5\" = recording-auth ] || exit 97\nprintf '%s' '{}'",
                hex::encode(&self.auth)
            ),
        );
    }
    fn command(&self, name: &str, body: &str) {
        let path = self.root.join("bin").join(name);
        fs::write(&path, format!("#!/bin/sh\n{body}\n")).unwrap();
        fs::set_permissions(path, fs::Permissions::from_mode(0o700)).unwrap();
    }
    fn settings(&self) -> settings::Settings {
        settings::Settings::load(&paths::settings_path().unwrap()).unwrap()
    }
    fn server(&self, address: &str) {
        let settings = settings::Settings {
            server: Some(address.to_string()),
            service: Some(settings::Service::Custom),
            ..settings::Settings::default()
        };
        settings.save(&paths::settings_path().unwrap()).unwrap();
    }
    fn recording(&self, name: &str, sample: i16) -> PathBuf {
        let path = paths::pending_dir().unwrap().join(name);
        let spec = hound::WavSpec {
            channels: 1,
            sample_rate: 16_000,
            bits_per_sample: 16,
            sample_format: hound::SampleFormat::Int,
        };
        let mut writer = hound::WavWriter::create(&path, spec).unwrap();
        for _ in 0..32_000 {
            writer.write_sample(sample).unwrap();
        }
        writer.finalize().unwrap();
        path
    }
    fn guard(&self, phase: state::State) -> state::StateGuard {
        state::StateGuard::begin(
            paths::state_path().unwrap(),
            paths::cancel_path().unwrap(),
            phase,
        )
        .unwrap()
    }
    fn run(&self, words: &[&str]) -> Result<(), String> {
        run(words.iter().map(|word| word.to_string()).collect())
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        for (name, value) in self.saved.drain(..).rev() {
            match value {
                Some(value) => std::env::set_var(name, value),
                None => std::env::remove_var(name),
            }
        }
        let _ = fs::remove_dir_all(&self.root);
    }
}

#[test]
fn settings_commands_persist_active_service_values_and_reject_without_a_write() {
    let fixture = Fixture::new();
    fixture
        .run(&["settings", "model", "gpt-4o-mini-transcribe"])
        .unwrap();
    fixture.run(&["settings", "language", "fr"]).unwrap();
    fixture.run(&["settings", "target", "en"]).unwrap();
    fixture.run(&["settings", "target", "toggle"]).unwrap();
    fixture.run(&["settings", "target", "toggle"]).unwrap();
    fixture.run(&["settings", "insert", "off"]).unwrap();
    fixture
        .run(&["settings", "translation-model", "gpt-5.4-mini"])
        .unwrap();
    let saved = fixture.settings();
    assert_eq!(saved.model, "gpt-4o-mini-transcribe");
    assert_eq!(saved.language.as_deref(), Some("fr"));
    assert_eq!(saved.target_language.as_deref(), Some("en"));
    assert!(!saved.auto_insert);
    for words in [
        vec!["settings", "model", "missing"],
        vec!["settings", "language", "bad;code"],
        vec!["settings", "target", "bad;code"],
        vec!["settings", "translation-model", "../model"],
        vec!["settings", "server", "ftp://private.invalid"],
        vec!["settings", "service", "custom"],
    ] {
        let path = paths::settings_path().unwrap();
        let before = fs::read(&path).unwrap();
        assert!(fixture.run(&words).is_err());
        assert_eq!(fs::read(&path).unwrap(), before);
    }
    fixture
        .run(&["settings", "server", "http://127.0.0.1:8080/v1"])
        .unwrap();
    fixture.run(&["settings", "model", "large-v3"]).unwrap();
    fixture
        .run(&["settings", "translation-model", "local-text"])
        .unwrap();
    fixture.run(&["settings", "service", "openai"]).unwrap();
    let saved = fixture.settings();
    assert_eq!(saved.model, "gpt-4o-mini-transcribe");
    assert_eq!(saved.custom_model, "large-v3");
    assert_eq!(saved.custom_translation_model, "local-text");
    fixture.run(&["settings", "service", "custom"]).unwrap();
    assert_eq!(
        fixture.settings().for_request().unwrap().0.model,
        "large-v3"
    );
    fixture.run(&["settings", "server", "off"]).unwrap();
    fixture.run(&["settings", "language", "auto"]).unwrap();
    fixture.run(&["settings", "target", "off"]).unwrap();
    fixture.run(&["settings", "insert", "on"]).unwrap();
    assert!(
        fixture.settings().language.is_none()
            && fixture.settings().target_language.is_none()
            && fixture.settings().auto_insert
    );
}

#[test]
fn failed_empty_cancelled_and_undelivered_processing_keeps_authenticated_audio() {
    let fixture = Fixture::new();
    for (name, status, body, expected_error) in [
        (
            "failed.wav",
            "503 Unavailable",
            "{}",
            "Transkription fehlgeschlagen",
        ),
        ("empty.wav", "200 OK", r#"{"text":""}"#, "Kein Text erkannt"),
        (
            "undelivered.wav",
            "200 OK",
            r#"{"text":"Fixture transcript."}"#,
            "Zwischenablage nicht verfügbar",
        ),
    ] {
        let (endpoint, stub) = test_http::serve(status, body);
        fixture.server(&endpoint);
        fixture.command("wl-copy", "/bin/cat >/dev/null\nexit 1");
        let path = fixture.recording(name, 8_000);
        let original = fs::read(&path).unwrap();
        let guard = fixture.guard(state::State::Processing);
        let error = process_new_recording(&path, None, &guard).unwrap_err();
        assert!(error.contains(expected_error), "{name}");
        stub.join().unwrap();
        let recovery_dir = paths::recovery_dir().unwrap();
        let kept = recovery_dir.join(name);
        assert_eq!(fs::read(&kept).unwrap(), original);
        assert!(!path.exists());
        // Retrieval authenticates the exact stored bytes, rather than existence alone.
        let (entry, authenticated) =
            recovery::newest_authenticated(&recovery_dir, &fixture.auth, false)
                .unwrap()
                .unwrap();
        assert_eq!(entry.audio_path, kept);
        assert_eq!(authenticated, original);
        recovery::delete(&entry).unwrap();
        drop(guard);
    }
    let path = fixture.recording("cancelled.wav", 8_000);
    let original = fs::read(&path).unwrap();
    let guard = fixture.guard(state::State::Processing);
    state::request_cancel(&paths::cancel_path().unwrap()).unwrap();
    let error = process_new_recording(&path, None, &guard).unwrap_err();
    assert!(error.contains("abgebrochen"));
    assert_eq!(
        fs::read(paths::recovery_dir().unwrap().join("cancelled.wav")).unwrap(),
        original
    );
}

#[test]
fn preservation_failure_keeps_all_originals_and_does_not_apply_the_five_copy_limit() {
    let fixture = Fixture::new();
    fixture.command("secret-tool", "exit 1");
    for index in 0..7 {
        let path = fixture.recording(&format!("original-{index}.wav"), 8_000);
        let original = fs::read(&path).unwrap();
        let guard = fixture.guard(state::State::Processing);
        state::request_cancel(&paths::cancel_path().unwrap()).unwrap();
        assert!(process_new_recording(&path, None, &guard)
            .unwrap_err()
            .contains("Original blieb erhalten"));
        assert_eq!(fs::read(path).unwrap(), original);
    }
    assert_eq!(
        fs::read_dir(paths::pending_dir().unwrap()).unwrap().count(),
        7
    );
    fixture.auth_available();
    // A valid auth lookup followed by a real filesystem copy failure also
    // keeps the only original. The blocker is owned by this fixture.
    fs::write(
        paths::state_dir().unwrap().join("recovery"),
        b"not a directory",
    )
    .unwrap();
    let path = fixture.recording("copy-failed.wav", 8_000);
    let original = fs::read(&path).unwrap();
    let guard = fixture.guard(state::State::Processing);
    state::request_cancel(&paths::cancel_path().unwrap()).unwrap();
    assert!(process_new_recording(&path, None, &guard)
        .unwrap_err()
        .contains("Original blieb erhalten"));
    assert_eq!(fs::read(path).unwrap(), original);
}

#[test]
fn retry_dispatch_sends_authenticated_bytes_and_requires_the_skipped_option() {
    let fixture = Fixture::new();
    let dir = paths::recovery_dir().unwrap();
    let skipped = fixture.recording("short.wav", 0);
    let skipped_bytes = fs::read(&skipped).unwrap();
    recovery::preserve(&skipped, &dir, &fixture.auth, true).unwrap();
    let refusal = fixture.run(&["retry"]).unwrap_err();
    assert!(refusal.contains("retry --skipped") && dir.join("short.wav").exists());
    let normal = fixture.recording("normal.wav", 8_000);
    let normal_bytes = fs::read(&normal).unwrap();
    recovery::preserve(&normal, &dir, &fixture.auth, false).unwrap();
    for (args, expected) in [
        (&["retry"][..], normal_bytes),
        (&["retry", "--skipped"][..], skipped_bytes),
    ] {
        let (endpoint, stub) = test_http::serve("200 OK", r#"{"text":"Fixture delivered."}"#);
        fixture.server(&endpoint);
        fixture.run(args).unwrap();
        let sent = stub.join().unwrap();
        assert!(sent.windows(expected.len()).any(|bytes| bytes == expected));
    }
    assert!(!dir.join("normal.wav").exists() && !dir.join("short.wav").exists());
}

#[test]
fn cancel_dispatch_covers_idle_starting_recording_processing_and_delivering() {
    let fixture = Fixture::new();
    assert!(fixture.run(&["cancel"]).is_err());
    assert!(!paths::cancel_path().unwrap().exists());
    for phase in [state::State::Processing, state::State::Delivering] {
        let socket = paths::socket_path().unwrap();
        let listener = ipc::bind_socket(&socket).unwrap();
        let guard = fixture.guard(phase);
        fixture.run(&["cancel"]).unwrap();
        assert!(guard.is_cancelled());
        drop(listener);
        fs::remove_file(socket).unwrap();
    }
    for phase in [state::State::Starting, state::State::Recording] {
        let socket = paths::socket_path().unwrap();
        let listener = ipc::bind_socket(&socket).unwrap();
        let guard = std::sync::Arc::new(fixture.guard(phase));
        let transition = std::sync::Arc::clone(&guard);
        let cancel_path = paths::cancel_path().unwrap();
        let worker = std::thread::spawn(move || {
            if phase == state::State::Starting {
                let deadline = Instant::now() + Duration::from_secs(2);
                while !cancel_path.exists() && Instant::now() < deadline {
                    std::thread::yield_now();
                }
                assert!(cancel_path.exists());
                // The real startup protocol can race into Recording after its check.
                transition.set(state::State::Recording).unwrap();
            }
            let Event::Stop(mut stream) =
                ipc::wait_for_stop(&listener, Instant::now() + Duration::from_secs(2), &|_| {})
            else {
                panic!("stop not received")
            };
            ipc::reply(&mut stream, ipc::PROCESSING).unwrap();
        });
        fixture.run(&["cancel"]).unwrap();
        worker.join().unwrap();
        assert!(guard.is_cancelled());
        drop(guard);
        fs::remove_file(socket).unwrap();
    }
}
