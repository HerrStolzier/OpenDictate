use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum State {
    Idle,
    Recording,
    Processing,
    Delivering,
}

impl State {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::Recording => "recording",
            Self::Processing => "processing",
            Self::Delivering => "delivering",
        }
    }

    fn parse(value: &str) -> Self {
        match value.trim() {
            "recording" => Self::Recording,
            "processing" => Self::Processing,
            "delivering" => Self::Delivering,
            _ => Self::Idle,
        }
    }
}

pub struct StateGuard {
    state_path: PathBuf,
    cancel_path: PathBuf,
}

impl StateGuard {
    pub fn begin(state_path: PathBuf, cancel_path: PathBuf, initial: State) -> io::Result<Self> {
        let _ = fs::remove_file(&cancel_path);
        write(&state_path, initial)?;
        Ok(Self {
            state_path,
            cancel_path,
        })
    }

    pub fn set(&self, state: State) -> io::Result<()> {
        write(&self.state_path, state)
    }

    pub fn is_cancelled(&self) -> bool {
        self.cancel_path.is_file()
    }
}

impl Drop for StateGuard {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.state_path);
        let _ = fs::remove_file(&self.cancel_path);
    }
}

pub fn read(path: &Path, socket_path: &Path) -> State {
    if !socket_path.exists() {
        return State::Idle;
    }
    fs::read_to_string(path)
        .map(|value| State::parse(&value))
        .unwrap_or(State::Idle)
}

pub fn request_cancel(path: &Path) -> io::Result<()> {
    fs::write(path, b"cancel\n")
}

fn write(path: &Path, state: State) -> io::Result<()> {
    let temporary = path.with_extension(format!("tmp-{}", std::process::id()));
    let result = (|| {
        let mut file = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .open(&temporary)?;
        file.write_all(format!("{}\n", state.as_str()).as_bytes())?;
        file.sync_all()?;
        fs::rename(&temporary, path)
    })();
    if result.is_err() {
        let _ = fs::remove_file(temporary);
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stale_state_without_socket_is_idle() {
        let dir = std::env::temp_dir().join(format!("opendictate-state-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        let state = dir.join("state");
        let socket = dir.join("socket");
        write(&state, State::Processing).unwrap();
        assert_eq!(read(&state, &socket), State::Idle);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn state_guard_clears_state_and_cancel() {
        let dir = std::env::temp_dir().join(format!("opendictate-guard-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        let state = dir.join("state");
        let cancel = dir.join("cancel");
        {
            let guard = StateGuard::begin(state.clone(), cancel.clone(), State::Recording).unwrap();
            guard.set(State::Processing).unwrap();
            request_cancel(&cancel).unwrap();
            assert!(guard.is_cancelled());
        }
        assert!(!state.exists());
        assert!(!cancel.exists());
        let _ = fs::remove_dir_all(&dir);
    }
}
