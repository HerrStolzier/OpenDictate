//! Real CLI output with private settings, command stubs and loopback HTTP.
use std::fs;
use std::io::{Read, Write};
use std::os::fd::FromRawFd;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::process::Command;
use std::time::{Duration, Instant};

struct Fixture(PathBuf);

impl Fixture {
    fn new() -> Self {
        let mut random = [0u8; 16];
        fs::File::open("/dev/urandom")
            .unwrap()
            .read_exact(&mut random)
            .unwrap();
        let root =
            std::env::temp_dir().join(format!("opendictate-settings-cli-{}", hex::encode(random)));
        fs::create_dir(&root).unwrap();
        Self(root)
    }

    fn command(&self, locale: &str) -> Command {
        let mut command = Command::new(env!("CARGO_BIN_EXE_opendictate"));
        command
            .env("XDG_CONFIG_HOME", &self.0)
            .env("LC_ALL", locale)
            .env_remove("OPENAI_BASE_URL");
        command
    }

    fn run(&self, args: &[&str], locale: &str, endpoint: Option<&str>) -> String {
        let mut command = self.command(locale);
        command.args(args);
        if let Some(endpoint) = endpoint {
            command.env("OPENAI_BASE_URL", endpoint);
        }
        let output = command.output().unwrap();
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        String::from_utf8(output.stdout).unwrap()
    }

    fn stub(&self, name: &str, body: &str) {
        let bin = self.0.join("bin");
        fs::create_dir_all(&bin).unwrap();
        let path = bin.join(name);
        fs::write(&path, format!("#!/bin/sh\n{body}\n")).unwrap();
        fs::set_permissions(path, fs::Permissions::from_mode(0o700)).unwrap();
    }

    fn setup(&self, answers: &str) -> String {
        let (mut master, mut slave) = (-1, -1);
        assert_eq!(
            unsafe {
                libc::openpty(
                    &mut master,
                    &mut slave,
                    std::ptr::null_mut(),
                    std::ptr::null(),
                    std::ptr::null(),
                )
            },
            0
        );
        let mut master = unsafe { fs::File::from_raw_fd(master) };
        let slave = unsafe { fs::File::from_raw_fd(slave) };
        let mut command = self.command("C");
        command
            .arg("setup")
            .env("PATH", self.0.join("bin"))
            .stdin(slave.try_clone().unwrap())
            .stdout(slave.try_clone().unwrap())
            .stderr(slave);
        let mut child = command.spawn().unwrap();
        drop(command);
        master.write_all(answers.as_bytes()).unwrap();
        let reader = std::thread::spawn(move || {
            let mut output = Vec::new();
            // A Linux PTY ends with EIO after the slave closes.
            let _ = master.take(1024 * 1024).read_to_end(&mut output);
            String::from_utf8_lossy(&output).into_owned()
        });
        let deadline = Instant::now() + Duration::from_secs(15);
        let status = loop {
            if let Some(status) = child.try_wait().unwrap() {
                break status;
            }
            if Instant::now() >= deadline {
                child.kill().unwrap();
                break child.wait().unwrap();
            }
            std::thread::sleep(Duration::from_millis(10));
        };
        let output = reader.join().unwrap();
        assert!(status.success(), "{output}");
        output
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

#[test]
fn saved_address_output_tracks_the_actual_service_in_both_languages() {
    let fixture = Fixture::new();
    fixture.run(
        &["settings", "server", "https://custom.invalid/v1"],
        "C",
        None,
    );
    fixture.run(&["settings", "service", "openai"], "C", None);
    let args = ["settings", "server", "https://changed.invalid/v1"];
    for (locale, active, inactive, key_notice) in [
        (
            "C",
            "Service: OpenAI",
            "The stored address is not active.",
            "Your stored API key is sent to this server.",
        ),
        (
            "de_DE.UTF-8",
            "Dienst: OpenAI",
            "Die gespeicherte Adresse ist nicht aktiv.",
            "Dein gespeicherter API-Schlüssel wird an diesen Server gesendet.",
        ),
    ] {
        let output = fixture.run(&args, locale, None);
        assert!(output.contains(active) && output.contains(inactive));
        assert!(output.contains("opendictate settings service custom"));
        assert!(!output.contains(key_notice));
    }
    let output = fixture.run(&args, "C", Some("http://127.0.0.1:9090/v1"));
    assert!(output.contains("Service: Custom server") && output.contains("OPENAI_BASE_URL"));
    assert!(output.contains("The stored address is not active."));
    assert!(!output.contains("Your stored API key is sent to this server."));

    fixture.run(&["settings", "service", "custom"], "C", None);
    let output = fixture.run(&args, "C", None);
    assert!(output.contains("Service: Custom server"));
    assert!(output.contains("Your stored API key is sent to this server."));
    assert!(!output.contains("The stored address is not active."));
}

#[test]
fn setup_saves_hold_for_manual_and_existing_shortcut_choices() {
    for (binds, answer, manual) in [
        ("[]", "2", false),
        ("[]", "3", true),
        (
            r#"[{"modmask":64,"key":"D","arg":"opendictate toggle"}]"#,
            "1",
            false,
        ),
    ] {
        let fixture = Fixture::new();
        fixture.stub("secret-tool", "printf 'fixture-present'");
        fixture.stub(
            "hyprctl",
            &format!("[ \"$1\" = binds ] || exit 1\nprintf '%s' '{binds}'"),
        );
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        listener.set_nonblocking(true).unwrap();
        let server = std::thread::spawn(move || {
            let deadline = Instant::now() + Duration::from_secs(5);
            let mut stream = loop {
                match listener.accept() {
                    Ok((stream, _)) => break stream,
                    Err(error)
                        if error.kind() == std::io::ErrorKind::WouldBlock
                            && Instant::now() < deadline =>
                    {
                        std::thread::sleep(Duration::from_millis(10))
                    }
                    Err(error) => panic!("setup did not query fixture: {error}"),
                }
            };
            stream
                .set_read_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            stream
                .set_write_timeout(Some(Duration::from_secs(5)))
                .unwrap();
            let mut request = Vec::new();
            let mut byte = [0u8; 1];
            while !request.ends_with(b"\r\n\r\n") && request.len() < 8192 {
                stream.read_exact(&mut byte).unwrap();
                request.push(byte[0]);
            }
            assert!(request.starts_with(b"GET /v1/models "));
            assert!(!String::from_utf8_lossy(&request).contains("Authorization"));
            stream
                .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}")
                .unwrap();
        });
        let output = fixture.setup(&format!("2\nhttp://{address}/v1\nlarge-v3\n2\n{answer}\n"));
        server.join().unwrap();
        let saved: serde_json::Value =
            serde_json::from_slice(&fs::read(fixture.0.join("opendictate/settings.json")).unwrap())
                .unwrap();
        assert_eq!(saved["shortcut_mode"], "hold");
        assert!(output.contains("opendictate start") && output.contains("opendictate stop"));
        assert!(output.contains(if manual {
            "Recording mode saved."
        } else {
            "Done. Hold"
        }));
        assert!(!fixture.0.join("hypr").exists());
    }
}
