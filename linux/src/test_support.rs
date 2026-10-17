//! Helpers shared by the unit tests.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, MutexGuard};
use std::time::{SystemTime, UNIX_EPOCH};

/// Serialises every test that reads or changes process environment
/// variables, since tests run on parallel threads of one process.
static ENV_LOCK: Mutex<()> = Mutex::new(());

pub fn env_lock() -> MutexGuard<'static, ()> {
    ENV_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Restores isolated test settings even when an assertion panics. Hold this
/// guard for every environment-dependent call, including subprocesses.
pub struct Environment {
    saved: Vec<(String, Option<std::ffi::OsString>)>,
    _lock: MutexGuard<'static, ()>,
}

impl Environment {
    pub fn new(values: &[(&str, Option<&std::ffi::OsStr>)]) -> Self {
        let lock = env_lock();
        let mut saved = Vec::new();
        for (name, value) in values {
            saved.push((name.to_string(), std::env::var_os(name)));
            match value {
                Some(value) => std::env::set_var(name, value),
                None => std::env::remove_var(name),
            }
        }
        Self { saved, _lock: lock }
    }
}

impl Drop for Environment {
    fn drop(&mut self) {
        for (name, value) in self.saved.iter().rev() {
            match value {
                Some(value) => std::env::set_var(name, value),
                None => std::env::remove_var(name),
            }
        }
    }
}

/// A fresh, empty directory under the system temp folder whose name another
/// local user cannot predict: it carries random bytes besides the process
/// id, and creation fails instead of reusing an existing path.
pub fn unique_temp_dir(name: &str) -> PathBuf {
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let mut random = [0u8; 8];
    std::fs::File::open("/dev/urandom")
        .and_then(|mut source| std::io::Read::read_exact(&mut source, &mut random))
        .unwrap();
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.subsec_nanos())
        .unwrap_or_default();
    let dir = std::env::temp_dir().join(format!(
        "opendictate-{name}-{}-{}-{nanos}-{}",
        std::process::id(),
        COUNTER.fetch_add(1, Ordering::Relaxed),
        hex::encode(random)
    ));
    std::fs::create_dir(&dir).unwrap();
    dir
}

/// Removes a file made inside `unique_temp_dir` together with its directory.
pub fn remove_temp_file(path: &Path) {
    if let Some(dir) = path.parent() {
        let _ = std::fs::remove_dir_all(dir);
    }
}
