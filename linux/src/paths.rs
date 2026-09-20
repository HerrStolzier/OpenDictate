use std::env;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

pub fn runtime_dir() -> io::Result<PathBuf> {
    let base = env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp").join(format!("opendictate-{}", usersafe_uid())));
    let dir = base.join("opendictate");
    fs::create_dir_all(&dir)?;
    restrict_owner_only(&dir)?;
    Ok(dir)
}

pub fn state_dir() -> io::Result<PathBuf> {
    let base = env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".local/state"));
    let dir = base.join("opendictate");
    fs::create_dir_all(&dir)?;
    restrict_owner_only(&dir)?;
    Ok(dir)
}

pub fn spike_dir() -> io::Result<PathBuf> {
    let dir = state_dir()?.join("spike");
    fs::create_dir_all(&dir)?;
    restrict_owner_only(&dir)?;
    Ok(dir)
}

pub fn socket_path() -> io::Result<PathBuf> {
    Ok(runtime_dir()?.join("spike.sock"))
}

pub fn worker_log_path() -> io::Result<PathBuf> {
    Ok(state_dir()?.join("spike.log"))
}

pub fn next_recording_path() -> io::Result<PathBuf> {
    let stamp = unix_timestamp_secs();
    Ok(spike_dir()?.join(format!("{stamp}.wav")))
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn usersafe_uid() -> u32 {
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        fs::metadata("/proc/self").map(|m| m.uid()).unwrap_or(0)
    }
    #[cfg(not(unix))]
    {
        0
    }
}

fn unix_timestamp_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn restrict_owner_only(path: &Path) -> io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(path)?.permissions();
        perms.set_mode(0o700);
        fs::set_permissions(path, perms)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn socket_path_uses_xdg_runtime_dir() {
        let _guard = ENV_LOCK.lock().unwrap();
        let tmp = std::env::temp_dir().join(format!("opendictate-paths-{}", std::process::id()));
        let _ = fs::remove_dir_all(&tmp);
        fs::create_dir_all(&tmp).unwrap();
        env::set_var("XDG_RUNTIME_DIR", &tmp);
        let path = socket_path().unwrap();
        assert_eq!(path, tmp.join("opendictate/spike.sock"));
        let _ = fs::remove_dir_all(&tmp);
        env::remove_var("XDG_RUNTIME_DIR");
    }
}
