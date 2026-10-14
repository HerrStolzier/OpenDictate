use std::env;
use std::ffi::OsString;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

/// Socket and state live in the session's private runtime directory. There
/// is no fallback to the shared `/tmp`, where another user could prepare the
/// path first.
pub fn runtime_dir() -> io::Result<PathBuf> {
    let base = env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .filter(|path| path.is_absolute())
        .ok_or_else(|| {
            io::Error::other(crate::tr!(
                "XDG_RUNTIME_DIR ist nicht gesetzt. Starte OpenDictate in einer Hyprland-Sitzung mit systemd-logind.",
                "XDG_RUNTIME_DIR is not set. Start OpenDictate inside a Hyprland session with systemd-logind."
            ))
        })?;
    let dir = base.join("opendictate");
    ensure_owner_directory(&dir)?;
    Ok(dir)
}

pub fn state_dir() -> io::Result<PathBuf> {
    let dir = state_home()?.join("opendictate");
    ensure_owner_directory(&dir)?;
    Ok(dir)
}

pub fn config_dir() -> io::Result<PathBuf> {
    let dir = config_home()?.join("opendictate");
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

/// `$XDG_STATE_HOME`, else `~/.local/state`.
pub fn state_home() -> io::Result<PathBuf> {
    xdg_base(
        env::var_os("XDG_STATE_HOME"),
        env::var_os("HOME"),
        ".local/state",
    )
}

/// `$XDG_CONFIG_HOME`, else `~/.config`.
pub fn config_home() -> io::Result<PathBuf> {
    xdg_base(
        env::var_os("XDG_CONFIG_HOME"),
        env::var_os("HOME"),
        ".config",
    )
}

/// Resolves an XDG base directory. The XDG spec says to ignore an empty or
/// relative value; without a usable home folder this fails instead of
/// falling back to a shared path such as `/tmp`.
fn xdg_base(
    xdg_value: Option<OsString>,
    home: Option<OsString>,
    home_suffix: &str,
) -> io::Result<PathBuf> {
    if let Some(base) = xdg_value
        .map(PathBuf::from)
        .filter(|path| path.is_absolute())
    {
        return Ok(base);
    }
    home.map(PathBuf::from)
        .filter(|path| path.is_absolute())
        .map(|home| home.join(home_suffix))
        .ok_or_else(|| {
            io::Error::other(crate::tr!(
                "HOME ist nicht gesetzt oder kein absoluter Pfad.",
                "HOME is not set or not an absolute path."
            ))
        })
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
            crate::tr!(
                "das OpenDictate-Verzeichnis ist kein echtes Verzeichnis",
                "the OpenDictate folder is not a real folder"
            ),
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
    use crate::test_support::{env_lock, unique_temp_dir};

    #[test]
    fn socket_path_uses_xdg_runtime_dir() {
        let _guard = env_lock();
        let tmp = unique_temp_dir("paths");
        env::set_var("XDG_RUNTIME_DIR", &tmp);
        let path = socket_path().unwrap();
        assert_eq!(path, tmp.join("opendictate/opendictate.sock"));
        let _ = fs::remove_dir_all(&tmp);
        env::remove_var("XDG_RUNTIME_DIR");
    }

    #[test]
    fn runtime_dir_refuses_to_fall_back_to_tmp() {
        let _guard = env_lock();
        env::remove_var("XDG_RUNTIME_DIR");
        let error = runtime_dir().unwrap_err();
        assert!(error.to_string().contains("XDG_RUNTIME_DIR"), "{error}");
        env::set_var("XDG_RUNTIME_DIR", "");
        assert!(runtime_dir().is_err());
        env::set_var("XDG_RUNTIME_DIR", "relative/run");
        assert!(runtime_dir().is_err());
        env::remove_var("XDG_RUNTIME_DIR");
    }

    #[cfg(unix)]
    #[test]
    fn app_directory_rejects_a_symbolic_link() {
        use std::os::unix::fs::symlink;

        let _guard = env_lock();
        let tmp = unique_temp_dir("path-link");
        let target = tmp.join("target");
        fs::create_dir_all(&target).unwrap();
        symlink(&target, tmp.join("opendictate")).unwrap();
        env::set_var("XDG_RUNTIME_DIR", &tmp);
        assert!(runtime_dir().is_err());
        env::remove_var("XDG_RUNTIME_DIR");
        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    fn xdg_base_uses_an_absolute_value() {
        let base = xdg_base(
            Some("/x/state".into()),
            Some("/home/a".into()),
            ".local/state",
        );
        assert_eq!(base.unwrap(), PathBuf::from("/x/state"));
    }

    #[test]
    fn xdg_base_ignores_empty_or_relative_values() {
        for value in ["", "relative/state", "./state"] {
            let base = xdg_base(Some(value.into()), Some("/home/a".into()), ".local/state");
            assert_eq!(base.unwrap(), PathBuf::from("/home/a/.local/state"));
        }
        let base = xdg_base(None, Some("/home/a".into()), ".config");
        assert_eq!(base.unwrap(), PathBuf::from("/home/a/.config"));
    }

    #[test]
    fn xdg_base_without_a_usable_home_is_an_error() {
        for home in [None, Some(""), Some("relative/home")] {
            let error = xdg_base(Some("".into()), home.map(OsString::from), ".config").unwrap_err();
            assert!(error.to_string().contains("HOME"), "{error}");
        }
    }
}
