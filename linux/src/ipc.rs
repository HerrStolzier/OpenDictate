use std::io::{self, Read, Write};
use std::os::unix::io::AsRawFd;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::Path;
use std::time::{Duration, Instant};

pub const STOP: &str = "stop";
pub const STATUS: &str = "status";
pub const RECORDING: &str = "recording";
pub const PROCESSING: &str = "processing";
#[cfg(test)]
pub const OK: &str = "ok";

pub enum Event {
    Stop(UnixStream),
    Timeout,
}

pub fn bind_socket(path: &Path) -> io::Result<UnixListener> {
    if path.exists() {
        match UnixStream::connect(path) {
            Ok(_) => {
                return Err(io::Error::new(
                    io::ErrorKind::AddrInUse,
                    crate::tr!("Aufnahme läuft bereits", "A recording is already running"),
                ));
            }
            Err(_) => {
                let _ = std::fs::remove_file(path);
            }
        }
    }
    let listener = UnixListener::bind(path)?;
    listener.set_nonblocking(true)?;
    Ok(listener)
}

/// How long one client may take to send its command or read the answer.
/// A client that stalls is dropped, so it cannot hold up the recording past
/// its deadline.
const CONNECTION_TIMEOUT: Duration = Duration::from_millis(500);

/// At most one log line per this interval for repeated accept errors.
const ACCEPT_ERROR_LOG_INTERVAL: Duration = Duration::from_secs(1);

/// Serves `status` and waits for `stop` until the deadline. A failing or
/// stalled connection is logged through `log` and skipped; it never ends the
/// recording.
pub fn wait_for_stop(listener: &UnixListener, deadline: Instant, log: &dyn Fn(&str)) -> Event {
    let mut last_accept_error: Option<Instant> = None;
    loop {
        match listener.accept() {
            Ok((stream, _)) => {
                if let Some(event) = serve_connection(stream, log) {
                    return event;
                }
            }
            Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                if Instant::now() >= deadline {
                    return Event::Timeout;
                }
                std::thread::sleep(Duration::from_millis(40));
                continue;
            }
            Err(error) => {
                let now = Instant::now();
                if accept_error_is_due(last_accept_error, now) {
                    log(&format!("ipc-accept-failed kind={:?}", error.kind()));
                    last_accept_error = Some(now);
                }
                std::thread::sleep(Duration::from_millis(40));
            }
        }
        if Instant::now() >= deadline {
            return Event::Timeout;
        }
    }
}

/// Whether a repeated accept error is logged again: the first one always,
/// then at most once per `ACCEPT_ERROR_LOG_INTERVAL`.
fn accept_error_is_due(last: Option<Instant>, now: Instant) -> bool {
    last.is_none_or(|last| now.duration_since(last) >= ACCEPT_ERROR_LOG_INTERVAL)
}

/// Answers one connection. Returns the stop event, or `None` once the
/// connection is done or failed.
fn serve_connection(mut stream: UnixStream, log: &dyn Fn(&str)) -> Option<Event> {
    let prepared = check_peer(&stream)
        .and_then(|()| stream.set_nonblocking(false))
        .and_then(|()| stream.set_read_timeout(Some(CONNECTION_TIMEOUT)))
        .and_then(|()| stream.set_write_timeout(Some(CONNECTION_TIMEOUT)));
    if let Err(error) = prepared {
        log(&format!("ipc-connection-refused kind={:?}", error.kind()));
        return None;
    }
    let command = match read_line(&mut stream) {
        Ok(command) => command,
        Err(error) => {
            log(&format!("ipc-read-failed kind={:?}", error.kind()));
            return None;
        }
    };
    match command.as_str() {
        STATUS => {
            if let Err(error) = reply(&mut stream, RECORDING) {
                log(&format!("ipc-write-failed kind={:?}", error.kind()));
            }
            None
        }
        STOP => Some(Event::Stop(stream)),
        _ => None,
    }
}

/// Accepts only clients of the same user. The socket folder is already
/// owner-only (0700); this is a second check on the connection itself.
fn check_peer(stream: &UnixStream) -> io::Result<()> {
    let mut credentials = libc::ucred {
        pid: 0,
        uid: 0,
        gid: 0,
    };
    let mut length = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
    // SAFETY: the descriptor stays open for the borrow of `stream`, and the
    // buffer and its length describe a valid, writable `ucred`.
    let result = unsafe {
        libc::getsockopt(
            stream.as_raw_fd(),
            libc::SOL_SOCKET,
            libc::SO_PEERCRED,
            (&mut credentials as *mut libc::ucred).cast(),
            &mut length,
        )
    };
    if result != 0 {
        return Err(io::Error::last_os_error());
    }
    // SAFETY: geteuid has no preconditions and cannot fail.
    if credentials.uid != unsafe { libc::geteuid() } {
        return Err(io::Error::from(io::ErrorKind::PermissionDenied));
    }
    Ok(())
}

pub fn send(path: &Path, command: &str) -> io::Result<String> {
    let mut stream = UnixStream::connect(path)?;
    stream.set_read_timeout(Some(Duration::from_secs(8)))?;
    stream.set_write_timeout(Some(Duration::from_secs(2)))?;
    stream.write_all(command.as_bytes())?;
    stream.write_all(b"\n")?;
    stream.shutdown(std::net::Shutdown::Write)?;
    read_line(&mut stream)
}

pub fn reply(stream: &mut UnixStream, message: &str) -> io::Result<()> {
    stream.write_all(message.as_bytes())?;
    stream.write_all(b"\n")?;
    Ok(())
}

#[cfg(test)]
pub fn reply_ok(stream: &mut UnixStream) -> io::Result<()> {
    reply(stream, OK)
}

fn read_line(stream: &mut UnixStream) -> io::Result<String> {
    let mut buf = Vec::new();
    let mut byte = [0u8; 1];
    loop {
        let n = stream.read(&mut byte)?;
        if n == 0 || byte[0] == b'\n' {
            break;
        }
        buf.push(byte[0]);
        if buf.len() > 64 {
            break;
        }
    }
    Ok(String::from_utf8_lossy(&buf).trim().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn stop_command_returns_the_stream() {
        let dir = crate::test_support::unique_temp_dir("ipc");
        let path = dir.join("spike.sock");
        let listener = UnixListener::bind(&path).unwrap();
        listener.set_nonblocking(true).unwrap();
        let server = thread::spawn(move || {
            wait_for_stop(&listener, Instant::now() + Duration::from_secs(2), &|_| {})
        });
        thread::sleep(Duration::from_millis(40));
        let client = thread::spawn(move || send(&path, STOP));
        match server.join().unwrap() {
            Event::Stop(mut stream) => reply_ok(&mut stream).unwrap(),
            Event::Timeout => panic!("timed out"),
        }
        assert_eq!(client.join().unwrap().unwrap(), OK);
        let _ = std::fs::remove_dir_all(&dir);
    }

    fn listener(name: &str) -> (std::path::PathBuf, UnixListener) {
        let dir = crate::test_support::unique_temp_dir(name);
        let path = dir.join("test.sock");
        let listener = bind_socket(&path).unwrap();
        (path, listener)
    }

    #[test]
    fn a_silent_client_does_not_hold_the_deadline() {
        let (path, listener) = listener("ipc-silent");
        let silent = UnixStream::connect(&path).unwrap();
        let started = Instant::now();
        let logged = std::cell::RefCell::new(Vec::new());
        let event = wait_for_stop(&listener, started + Duration::from_millis(200), &|line| {
            logged.borrow_mut().push(line.to_string())
        });
        assert!(matches!(event, Event::Timeout));
        assert_eq!(logged.into_inner(), ["ipc-read-failed kind=WouldBlock"]);
        assert!(started.elapsed() < CONNECTION_TIMEOUT + Duration::from_secs(1));
        drop(silent);
        crate::test_support::remove_temp_file(&path);
    }

    #[test]
    fn a_stalled_client_is_skipped_and_a_later_stop_still_works() {
        let (path, listener) = listener("ipc-stalled");
        let server = thread::spawn(move || {
            wait_for_stop(&listener, Instant::now() + Duration::from_secs(5), &|_| {})
        });
        let silent = UnixStream::connect(&path).unwrap();
        let mut gone = UnixStream::connect(&path).unwrap();
        gone.write_all(STATUS.as_bytes()).unwrap();
        drop(gone);
        assert_eq!(send(&path, STATUS).unwrap(), RECORDING);
        let stopper = {
            let path = path.clone();
            thread::spawn(move || send(&path, STOP))
        };
        match server.join().unwrap() {
            Event::Stop(mut stream) => reply_ok(&mut stream).unwrap(),
            Event::Timeout => panic!("timed out"),
        }
        assert_eq!(stopper.join().unwrap().unwrap(), OK);
        drop(silent);
        crate::test_support::remove_temp_file(&path);
    }

    #[test]
    fn the_same_user_passes_the_peer_check() {
        let (path, listener) = listener("ipc-peer");
        let _client = UnixStream::connect(&path).unwrap();
        let (stream, _) = loop {
            match listener.accept() {
                Ok(accepted) => break accepted,
                Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                    thread::sleep(Duration::from_millis(5));
                }
                Err(error) => panic!("{error}"),
            }
        };
        check_peer(&stream).unwrap();
        crate::test_support::remove_temp_file(&path);
    }

    #[test]
    fn repeated_accept_errors_are_logged_once_per_second() {
        let start = Instant::now();
        assert!(accept_error_is_due(None, start));
        assert!(!accept_error_is_due(
            Some(start),
            start + Duration::from_millis(999)
        ));
        assert!(accept_error_is_due(
            Some(start),
            start + ACCEPT_ERROR_LOG_INTERVAL
        ));
    }
}
