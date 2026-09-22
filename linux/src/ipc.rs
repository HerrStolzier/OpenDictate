use std::io::{self, Read, Write};
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
                    "Aufnahme läuft bereits",
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

pub fn wait_for_stop(listener: &UnixListener, deadline: Instant) -> io::Result<Event> {
    loop {
        match listener.accept() {
            Ok((mut stream, _)) => {
                let command = read_line(&mut stream)?;
                if command == STATUS {
                    stream.write_all(RECORDING.as_bytes())?;
                    stream.write_all(b"\n")?;
                    continue;
                }
                if command == STOP {
                    return Ok(Event::Stop(stream));
                }
            }
            Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                if Instant::now() >= deadline {
                    return Ok(Event::Timeout);
                }
                std::thread::sleep(Duration::from_millis(40));
            }
            Err(error) => return Err(error),
        }
    }
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
        let dir = std::env::temp_dir().join(format!("opendictate-ipc-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("spike.sock");
        let listener = UnixListener::bind(&path).unwrap();
        listener.set_nonblocking(true).unwrap();
        let server = thread::spawn(move || {
            wait_for_stop(&listener, Instant::now() + Duration::from_secs(2))
        });
        thread::sleep(Duration::from_millis(40));
        let client = thread::spawn(move || send(&path, STOP));
        match server.join().unwrap().unwrap() {
            Event::Stop(mut stream) => reply_ok(&mut stream).unwrap(),
            Event::Timeout => panic!("timed out"),
        }
        assert_eq!(client.join().unwrap().unwrap(), OK);
        let _ = std::fs::remove_dir_all(&dir);
    }
}
