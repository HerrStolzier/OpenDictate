use std::fs::{self, OpenOptions};
use std::io::Write;
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use hmac::{Hmac, KeyInit, Mac};
use serde::{Deserialize, Serialize};
use sha2::Sha256;

const KEEP_COUNT: usize = 5;
const MAXIMUM_AGE: Duration = Duration::from_secs(24 * 60 * 60);
const MAX_AUDIO_BYTES: u64 = 25 * 1_024 * 1_024;

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, Serialize, Deserialize)]
struct Sidecar {
    version: u8,
    created: u64,
    size: u64,
    mac: String,
    /// Set for a recording that was too short or silent to be sent. Plain
    /// `retry` passes it over; the retention limits treat it like any other.
    #[serde(default, skip_serializing_if = "is_false")]
    skipped: bool,
}

fn is_false(value: &bool) -> bool {
    !*value
}

#[derive(Debug, Clone)]
pub struct Entry {
    pub audio_path: PathBuf,
    pub sidecar_path: PathBuf,
    pub created: u64,
    pub skipped: bool,
}

pub fn preserve(
    original: &Path,
    recovery_dir: &Path,
    key: &[u8],
    skipped: bool,
) -> Result<Entry, String> {
    let metadata = fs::symlink_metadata(original).map_err(|_| {
        crate::tr!(
            "Die Aufnahme ließ sich nicht sichern.",
            "The recording could not be kept."
        )
    })?;
    if !metadata.file_type().is_file() || metadata.len() == 0 || metadata.len() > MAX_AUDIO_BYTES {
        return Err(crate::tr!(
            "Diese Aufnahme lässt sich nicht sichern.",
            "This recording cannot be kept."
        ));
    }
    let directory_metadata = fs::symlink_metadata(recovery_dir).map_err(|_| {
        crate::tr!(
            "Sicherungsordner nicht verfügbar.",
            "Folder for kept recordings unavailable."
        )
    })?;
    if !directory_metadata.file_type().is_dir() || directory_metadata.file_type().is_symlink() {
        return Err(crate::tr!(
            "Sicherungsordner ist unsicher.",
            "Folder for kept recordings is not secure."
        ));
    }
    fs::set_permissions(recovery_dir, fs::Permissions::from_mode(0o700)).map_err(|_| {
        crate::tr!(
            "Sicherungsordner nicht verfügbar.",
            "Folder for kept recordings unavailable."
        )
    })?;
    let file_name = original
        .file_name()
        .and_then(|value| value.to_str())
        .filter(|value| value.ends_with(".wav"))
        .ok_or_else(|| crate::tr!("Aufnahmedatei ist ungültig.", "Recording file is invalid."))?;
    let audio_path = recovery_dir.join(file_name);
    let sidecar_path = sidecar_path(&audio_path);
    let data = fs::read(original).map_err(|_| {
        crate::tr!(
            "Die Aufnahme ließ sich zum Sichern nicht lesen.",
            "The recording could not be read to keep it."
        )
    })?;
    let created = unix_timestamp_secs();
    let sidecar = Sidecar {
        version: 1,
        created,
        size: data.len() as u64,
        mac: authentication(file_name, created, &data, skipped, key)?,
        skipped,
    };
    let result = write_pair(&audio_path, &sidecar_path, &data, &sidecar);
    if result.is_err() {
        let _ = fs::remove_file(&audio_path);
        let _ = fs::remove_file(&sidecar_path);
        return result.map(|_| unreachable!());
    }
    fs::remove_file(original).map_err(|_| {
        crate::tr!(
            "Die Aufnahme ist gesichert, aber das Original ließ sich nicht aufräumen.",
            "The recording is kept, but the original could not be cleaned up."
        )
    })?;
    let entry = Entry {
        audio_path,
        sidecar_path,
        created,
        skipped,
    };
    let _ = prune(recovery_dir, key);
    Ok(entry)
}

/// The newest kept recording that has not expired, among the skipped ones
/// (too short or silent) or among all others.
pub fn newest_authenticated(
    recovery_dir: &Path,
    key: &[u8],
    skipped: bool,
) -> Result<Option<(Entry, Vec<u8>)>, String> {
    let mut entries = authenticated_entries(recovery_dir, key)?;
    let now = unix_timestamp_secs();
    entries.retain(|(entry, _)| {
        now.saturating_sub(entry.created) < MAXIMUM_AGE.as_secs() && entry.skipped == skipped
    });
    entries.sort_by(|left, right| {
        right
            .0
            .created
            .cmp(&left.0.created)
            .then_with(|| right.0.audio_path.cmp(&left.0.audio_path))
    });
    Ok(entries.into_iter().next())
}

pub fn delete(entry: &Entry) -> Result<(), String> {
    fs::remove_file(&entry.audio_path).map_err(|_| {
        crate::tr!(
            "Gesicherte Aufnahme konnte nicht gelöscht werden.",
            "Kept recording could not be deleted."
        )
    })?;
    let _ = fs::remove_file(&entry.sidecar_path);
    Ok(())
}

pub fn prune(recovery_dir: &Path, key: &[u8]) -> Result<(), String> {
    let mut entries = authenticated_entries(recovery_dir, key)?;
    let now = unix_timestamp_secs();
    entries.sort_by(|left, right| {
        right
            .0
            .created
            .cmp(&left.0.created)
            .then_with(|| right.0.audio_path.cmp(&left.0.audio_path))
    });
    for (index, (entry, _)) in entries.into_iter().enumerate() {
        let expired = now.saturating_sub(entry.created) >= MAXIMUM_AGE.as_secs();
        if expired || index >= KEEP_COUNT {
            delete(&entry)?;
        }
    }
    Ok(())
}

/// Whether the folder holds any recording with a proof, checked without the
/// key. Files without one are never managed, so they need no key lookup.
pub fn has_recordings(recovery_dir: &Path) -> bool {
    fs::read_dir(recovery_dir).is_ok_and(|directory| {
        directory.flatten().any(|item| {
            item.file_name()
                .to_str()
                .is_some_and(|name| name.ends_with(".wav.auth.json"))
        })
    })
}

fn authenticated_entries(recovery_dir: &Path, key: &[u8]) -> Result<Vec<(Entry, Vec<u8>)>, String> {
    if !recovery_dir.exists() {
        return Ok(Vec::new());
    }
    let directory = fs::read_dir(recovery_dir).map_err(|_| {
        crate::tr!(
            "Sicherungsordner nicht lesbar.",
            "Folder for kept recordings unreadable."
        )
    })?;
    let mut entries = Vec::new();
    for item in directory.flatten() {
        let path = item.path();
        if path.extension().and_then(|value| value.to_str()) != Some("wav") {
            continue;
        }
        if let Ok(entry) = authenticate(&path, key) {
            entries.push(entry);
        }
    }
    Ok(entries)
}

fn authenticate(audio_path: &Path, key: &[u8]) -> Result<(Entry, Vec<u8>), String> {
    let metadata = fs::symlink_metadata(audio_path)
        .map_err(|_| crate::tr!("Gesicherte Aufnahme fehlt.", "Kept recording is missing."))?;
    if !metadata.file_type().is_file() || metadata.len() == 0 || metadata.len() > MAX_AUDIO_BYTES {
        return Err(crate::tr!(
            "Gesicherte Aufnahme ist ungültig.",
            "Kept recording is invalid."
        ));
    }
    let sidecar_path = sidecar_path(audio_path);
    let sidecar_metadata = fs::symlink_metadata(&sidecar_path).map_err(|_| {
        crate::tr!(
            "Sicherungsnachweis fehlt.",
            "Proof for the kept recording is missing."
        )
    })?;
    if !sidecar_metadata.file_type().is_file() {
        return Err(crate::tr!(
            "Sicherungsnachweis ist ungültig.",
            "Proof for the kept recording is invalid."
        ));
    }
    let sidecar: Sidecar = serde_json::from_slice(&fs::read(&sidecar_path).map_err(|_| {
        crate::tr!(
            "Sicherungsnachweis ist nicht lesbar.",
            "Proof for the kept recording is unreadable."
        )
    })?)
    .map_err(|_| {
        crate::tr!(
            "Sicherungsnachweis ist ungültig.",
            "Proof for the kept recording is invalid."
        )
    })?;
    if sidecar.version != 1 || sidecar.size != metadata.len() {
        return Err(crate::tr!(
            "Sicherungsnachweis passt nicht zur Aufnahme.",
            "Proof does not match the kept recording."
        ));
    }
    let data = fs::read(audio_path).map_err(|_| {
        crate::tr!(
            "Gesicherte Aufnahme ist nicht lesbar.",
            "Kept recording is unreadable."
        )
    })?;
    let file_name = audio_path
        .file_name()
        .and_then(|value| value.to_str())
        .ok_or_else(|| {
            crate::tr!(
                "Gesicherte Aufnahme ist ungültig.",
                "Kept recording is invalid."
            )
        })?;
    verify_authentication(
        file_name,
        sidecar.created,
        &data,
        sidecar.skipped,
        key,
        &sidecar.mac,
    )?;
    Ok((
        Entry {
            audio_path: audio_path.to_path_buf(),
            sidecar_path,
            created: sidecar.created,
            skipped: sidecar.skipped,
        },
        data,
    ))
}

fn write_pair(
    audio_path: &Path,
    sidecar_path: &Path,
    data: &[u8],
    sidecar: &Sidecar,
) -> Result<(), String> {
    let mut audio = secure_create(audio_path)?;
    audio
        .write_all(data)
        .and_then(|_| audio.sync_all())
        .map_err(|_| {
            crate::tr!(
                "Gesicherte Kopie konnte nicht geschrieben werden.",
                "Kept copy could not be written."
            )
        })?;
    let mut proof = secure_create(sidecar_path)?;
    let proof_data = serde_json::to_vec(sidecar).map_err(|_| {
        crate::tr!(
            "Sicherungsnachweis konnte nicht erstellt werden.",
            "Proof for the kept recording could not be created."
        )
    })?;
    proof
        .write_all(&proof_data)
        .and_then(|_| proof.write_all(b"\n"))
        .and_then(|_| proof.sync_all())
        .map_err(|_| {
            crate::tr!(
                "Sicherungsnachweis konnte nicht geschrieben werden.",
                "Proof for the kept recording could not be written."
            )
        })
}

fn secure_create(path: &Path) -> Result<fs::File, String> {
    OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(path)
        .map_err(|_| {
            crate::tr!(
                "Sicherungsdatei konnte nicht erstellt werden.",
                "File for the kept recording could not be created."
            )
        })
}

fn sidecar_path(audio_path: &Path) -> PathBuf {
    audio_path.with_extension("wav.auth.json")
}

fn authentication(
    file_name: &str,
    created: u64,
    data: &[u8],
    skipped: bool,
    key: &[u8],
) -> Result<String, String> {
    let mut mac = HmacSha256::new_from_slice(key).map_err(|_| {
        crate::tr!(
            "Der Sicherungsschlüssel ist ungültig.",
            "The key for kept recordings is invalid."
        )
    })?;
    update_mac(&mut mac, file_name, created, data, skipped);
    Ok(hex::encode(mac.finalize().into_bytes()))
}

fn verify_authentication(
    file_name: &str,
    created: u64,
    data: &[u8],
    skipped: bool,
    key: &[u8],
    expected: &str,
) -> Result<(), String> {
    let expected = hex::decode(expected).map_err(|_| {
        crate::tr!(
            "Sicherungsnachweis ist ungültig.",
            "Proof for the kept recording is invalid."
        )
    })?;
    let mut mac = HmacSha256::new_from_slice(key).map_err(|_| {
        crate::tr!(
            "Der Sicherungsschlüssel ist ungültig.",
            "The key for kept recordings is invalid."
        )
    })?;
    update_mac(&mut mac, file_name, created, data, skipped);
    mac.verify_slice(&expected).map_err(|_| {
        crate::tr!(
            "Gesicherte Aufnahme lässt sich nicht bestätigen.",
            "Kept recording could not be verified."
        )
    })
}

fn update_mac(mac: &mut HmacSha256, file_name: &str, created: u64, data: &[u8], skipped: bool) {
    mac.update(b"OpenDictate-Linux-Recovery-v1\0");
    mac.update(file_name.as_bytes());
    mac.update(b"\0");
    mac.update(&created.to_be_bytes());
    mac.update(&(data.len() as u64).to_be_bytes());
    mac.update(data);
    // Appended only when set, so tags of earlier recordings stay valid and
    // the flag cannot be removed without the key.
    if skipped {
        mac.update(b"\0skipped");
    }
}

fn unix_timestamp_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|value| value.as_secs())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Read;

    /// A fresh random key, so tests never depend on a fixed secret.
    fn test_key() -> Vec<u8> {
        let mut key = Vec::with_capacity(32);
        fs::File::open("/dev/urandom")
            .and_then(|source| source.take(32).read_to_end(&mut key))
            .unwrap();
        assert_eq!(key.len(), 32);
        key
    }

    fn fixture(name: &str) -> (PathBuf, PathBuf) {
        let root = crate::test_support::unique_temp_dir(&format!("recovery-{name}"));
        let pending = root.join("pending");
        let recovery = root.join("recovery");
        fs::create_dir_all(&pending).unwrap();
        fs::create_dir_all(&recovery).unwrap();
        (pending.join("123.wav"), recovery)
    }

    #[test]
    fn preserve_authenticates_exact_bytes_and_removes_original_after_copy() {
        let (original, recovery_dir) = fixture("roundtrip");
        fs::write(&original, b"audio-bytes").unwrap();
        let key = test_key();
        preserve(&original, &recovery_dir, &key, false).unwrap();
        assert!(!original.exists());
        let (_, data) = newest_authenticated(&recovery_dir, &key, false)
            .unwrap()
            .unwrap();
        assert_eq!(data, b"audio-bytes");
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }

    #[test]
    fn changed_bytes_and_wrong_key_are_never_returned() {
        let (original, recovery_dir) = fixture("tamper");
        fs::write(&original, b"audio-bytes").unwrap();
        let key = test_key();
        let entry = preserve(&original, &recovery_dir, &key, false).unwrap();
        assert!(newest_authenticated(&recovery_dir, &test_key(), false)
            .unwrap()
            .is_none());
        fs::write(&entry.audio_path, b"changed").unwrap();
        assert!(newest_authenticated(&recovery_dir, &key, false)
            .unwrap()
            .is_none());
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }

    #[test]
    fn authentication_binds_the_file_name() {
        let (original, recovery_dir) = fixture("rename");
        fs::write(&original, b"audio-bytes").unwrap();
        let key = test_key();
        let entry = preserve(&original, &recovery_dir, &key, false).unwrap();
        let renamed_audio = recovery_dir.join("renamed.wav");
        let renamed_sidecar = sidecar_path(&renamed_audio);
        fs::rename(&entry.audio_path, &renamed_audio).unwrap();
        fs::rename(&entry.sidecar_path, &renamed_sidecar).unwrap();
        assert!(newest_authenticated(&recovery_dir, &key, false)
            .unwrap()
            .is_none());
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }

    #[test]
    fn authentication_tag_stays_stable_across_crate_updates() {
        // Reference HMAC-SHA256 computed independently (Python `hmac`), so
        // recordings kept by an earlier build still verify after an update.
        let key: Vec<u8> = (0u8..32).collect();
        assert_eq!(
            authentication("recording.wav", 1_700_000_000, b"OpenDictate", false, &key).unwrap(),
            "c6060393f092b6610d2b728711551693157292e19b8eb350dc1704f600969605"
        );
    }

    #[test]
    fn failed_copy_keeps_the_only_original() {
        let (original, recovery_dir) = fixture("failure");
        fs::write(&original, b"audio-bytes").unwrap();
        fs::write(recovery_dir.join("123.wav"), b"collision").unwrap();
        assert!(preserve(&original, &recovery_dir, &test_key(), false).is_err());
        assert_eq!(fs::read(&original).unwrap(), b"audio-bytes");
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }

    #[test]
    fn prune_keeps_five_and_removes_authenticated_expired_entries() {
        let (_, recovery_dir) = fixture("retention");
        let key = test_key();
        let now = unix_timestamp_secs();
        for index in 0..6u64 {
            let file_name = format!("{index}.wav");
            let audio_path = recovery_dir.join(&file_name);
            let data = format!("audio-{index}").into_bytes();
            let created = now - (5 - index);
            let sidecar = Sidecar {
                version: 1,
                created,
                size: data.len() as u64,
                mac: authentication(&file_name, created, &data, false, &key).unwrap(),
                skipped: false,
            };
            write_pair(&audio_path, &sidecar_path(&audio_path), &data, &sidecar).unwrap();
        }
        let expired_name = "expired.wav";
        let expired_path = recovery_dir.join(expired_name);
        let expired_data = b"expired";
        let expired_created = now - MAXIMUM_AGE.as_secs();
        let expired_sidecar = Sidecar {
            version: 1,
            created: expired_created,
            size: expired_data.len() as u64,
            mac: authentication(expired_name, expired_created, expired_data, false, &key).unwrap(),
            skipped: false,
        };
        write_pair(
            &expired_path,
            &sidecar_path(&expired_path),
            expired_data,
            &expired_sidecar,
        )
        .unwrap();
        prune(&recovery_dir, &key).unwrap();
        let wav_count = fs::read_dir(&recovery_dir)
            .unwrap()
            .flatten()
            .filter(|item| item.path().extension().and_then(|value| value.to_str()) == Some("wav"))
            .count();
        assert_eq!(wav_count, KEEP_COUNT);
        assert!(!recovery_dir.join("0.wav").exists());
        assert!(!expired_path.exists());
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }

    #[test]
    fn only_recordings_with_a_proof_count_as_kept() {
        let (_, recovery_dir) = fixture("has-recordings");
        assert!(!has_recordings(&recovery_dir));
        fs::write(recovery_dir.join("legacy.wav"), b"audio").unwrap();
        assert!(!has_recordings(&recovery_dir));
        fs::write(recovery_dir.join("1.wav.auth.json"), b"{}").unwrap();
        assert!(has_recordings(&recovery_dir));
        assert!(!has_recordings(&recovery_dir.join("missing")));
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }

    fn keep(recovery_dir: &Path, name: &str, created: u64, skipped: bool, key: &[u8]) -> PathBuf {
        let audio_path = recovery_dir.join(name);
        let data = name.as_bytes();
        let sidecar = Sidecar {
            version: 1,
            created,
            size: data.len() as u64,
            mac: authentication(name, created, data, skipped, key).unwrap(),
            skipped,
        };
        write_pair(&audio_path, &sidecar_path(&audio_path), data, &sidecar).unwrap();
        audio_path
    }

    #[test]
    fn plain_retry_passes_over_skipped_recordings() {
        let (_, recovery_dir) = fixture("skipped-retry");
        let key = test_key();
        let now = unix_timestamp_secs();
        assert!(newest_authenticated(&recovery_dir, &key, false)
            .unwrap()
            .is_none());
        keep(&recovery_dir, "real.wav", now - 10, false, &key);
        keep(&recovery_dir, "short.wav", now, true, &key);
        let (entry, _) = newest_authenticated(&recovery_dir, &key, false)
            .unwrap()
            .unwrap();
        assert!(entry.audio_path.ends_with("real.wav"));
        let (entry, _) = newest_authenticated(&recovery_dir, &key, true)
            .unwrap()
            .unwrap();
        assert!(entry.skipped && entry.audio_path.ends_with("short.wav"));
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }

    #[test]
    fn the_skipped_flag_cannot_be_removed_without_the_key() {
        let (_, recovery_dir) = fixture("skipped-flag");
        let key = test_key();
        let audio_path = keep(
            &recovery_dir,
            "short.wav",
            unix_timestamp_secs(),
            true,
            &key,
        );
        let proof = sidecar_path(&audio_path);
        let edited = fs::read_to_string(&proof)
            .unwrap()
            .replace(",\"skipped\":true", "");
        fs::write(&proof, edited).unwrap();
        assert!(newest_authenticated(&recovery_dir, &key, true)
            .unwrap()
            .is_none());
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }

    #[test]
    fn skipped_recordings_count_toward_the_five_newest() {
        let (_, recovery_dir) = fixture("skipped-prune");
        let key = test_key();
        let now = unix_timestamp_secs();
        for index in 0..KEEP_COUNT as u64 {
            keep(
                &recovery_dir,
                &format!("real-{index}.wav"),
                now - 20 + index,
                false,
                &key,
            );
        }
        let skipped = keep(&recovery_dir, "short.wav", now, true, &key);
        prune(&recovery_dir, &key).unwrap();
        assert!(skipped.exists());
        assert!(!recovery_dir.join("real-0.wav").exists());
        assert!(recovery_dir.join("real-1.wav").exists());
        let _ = fs::remove_dir_all(recovery_dir.parent().unwrap());
    }
}
