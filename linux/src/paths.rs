use std::env;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

/// Socket and state live in the session's private runtime directory. There
/// is no fallback to the shared `/tmp`, where another user could prepare the
/// path first.
pub fn runtime_dir() -> io::Result<PathBuf> {
    let base = env::var_os("XDG_RUNTIME_DIR")
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| {
            io::Error::other(crate::tr!(
                "XDG_RUNTIME_DIR ist nicht gesetzt; bitte in einer Hyprland-Sitzung mit systemd-logind starten.",
                "XDG_RUNTIME_DIR is not set; please start inside a Hyprland session with systemd-logind."
            ))
        })?;
    let dir = base.join("opendictate");
    ensure_owner_directory(&dir)?;
    Ok(dir)
}

pub fn state_dir() -> io::Result<PathBuf> {
    let base = env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".local/state"));
    let dir = base.join("opendictate");
    ensure_owner_directory(&dir)?;
    Ok(dir)
}

pub fn config_dir() -> io::Result<PathBuf> {
    let base = env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".config"));
    let dir = base.join("opendictate");
    ensure_owner_directory(&dir)?;
    Ok(dir)
}

pub fn pending_dir() -> io::Result<PathBuf> {
    let dir = state_dir()?.join("pending");
    ensure_owner_directory(&dir)?;
    Ok(dir)
}

pub fn recovery_dir() -> io::Result<PathBuf> {
    let dir = state_dir()?.join("recovery");
    ensure_owner_directory(&dir)?;
    Ok(dir)
}

pub fn socket_path() -> io::Result<PathBuf> {
    Ok(runtime_dir()?.join("opendictate.sock"))
}

pub fn state_path() -> io::Result<PathBuf> {
    Ok(runtime_dir()?.join("state"))
}

pub fn cancel_path() -> io::Result<PathBuf> {
    Ok(runtime_dir()?.join("cancel"))
}

pub fn toggle_lock_path() -> io::Result<PathBuf> {
    Ok(runtime_dir()?.join("toggle.lock"))
}

pub fn worker_log_path() -> io::Result<PathBuf> {
    Ok(state_dir()?.join("operations.log"))
}

pub fn settings_path() -> io::Result<PathBuf> {
    Ok(config_dir()?.join("settings.json"))
}

pub fn next_pending_path() -> io::Result<PathBuf> {
    let stamp = unix_timestamp_millis();
    Ok(pending_dir()?.join(format!("{stamp}-{}.wav", std::process::id())))
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn unix_timestamp_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

fn ensure_owner_directory(path: &Path) -> io::Result<()> {
    fs::create_dir_all(path)?;
    let metadata = fs::symlink_metadata(path)?;
    if !metadata.file_type().is_dir() || metadata.file_type().is_symlink() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "OpenDictate directory is not a real directory",
        ));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = metadata.permissions();
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
        assert_eq!(path, tmp.join("opendictate/opendictate.sock"));
        let _ = fs::remove_dir_all(&tmp);
        env::remove_var("XDG_RUNTIME_DIR");
    }

    #[test]
    fn runtime_dir_refuses_to_fall_back_to_tmp() {
        let _guard = ENV_LOCK.lock().unwrap();
        env::remove_var("XDG_RUNTIME_DIR");
        let error = runtime_dir().unwrap_err();
        assert!(error.to_string().contains("XDG_RUNTIME_DIR"), "{error}");
        env::set_var("XDG_RUNTIME_DIR", "");
        assert!(runtime_dir().is_err());
        env::remove_var("XDG_RUNTIME_DIR");
    }

    #[cfg(unix)]
    #[test]
    fn app_directory_rejects_a_symbolic_link() {
        use std::os::unix::fs::symlink;

        let _guard = ENV_LOCK.lock().unwrap();
        let tmp =
            std::env::temp_dir().join(format!("opendictate-path-link-{}", std::process::id()));
        let target = tmp.join("target");
        fs::create_dir_all(&target).unwrap();
        symlink(&target, tmp.join("opendictate")).unwrap();
        env::set_var("XDG_RUNTIME_DIR", &tmp);
        assert!(runtime_dir().is_err());
        env::remove_var("XDG_RUNTIME_DIR");
        let _ = fs::remove_dir_all(&tmp);
    }
}
