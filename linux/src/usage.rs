//! Local estimates only. No provider-account request, transcripts or filenames.

use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::unix::fs::OpenOptionsExt;
use std::os::unix::io::AsRawFd;
use std::path::Path;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Translation {
    pub model: String,
    pub input_tokens: Option<u64>,
    pub output_tokens: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub timestamp: i64,
    pub custom: bool,
    pub model: String,
    pub audio_seconds: f64,
    pub translation: Option<Translation>,
}

#[derive(Clone, Copy, Deserialize)]
pub struct Bounds {
    pub today: i64,
    pub week: i64,
    pub month: i64,
    pub retention: i64,
}

#[derive(Debug)]
pub struct Total {
    pub dictations: usize,
    pub audio_seconds: f64,
    pub cost_usd: Option<f64>,
}

fn prices() -> serde_json::Value {
    serde_json::from_str(include_str!("../../fixtures/pricing/prices.json"))
        .expect("checked-in prices")
}

fn cost(entry: &Entry, prices: &serde_json::Value) -> Option<f64> {
    if entry.custom {
        return Some(0.0);
    }
    let mut cost = entry.audio_seconds / 60.0 * prices["transcription"][&entry.model].as_f64()?;
    if let Some(translation) = &entry.translation {
        let price = &prices["translation"][&translation.model];
        cost += (translation.input_tokens? as f64 * price["input_per_million"].as_f64()?
            + translation.output_tokens? as f64 * price["output_per_million"].as_f64()?)
            / 1_000_000.0;
    }
    Some(cost)
}

pub fn totals(entries: &[Entry], now: i64, bounds: Bounds) -> [Total; 3] {
    let prices = prices();
    [bounds.today, bounds.week, bounds.month].map(|start| {
        let mut result = Total {
            dictations: 0,
            audio_seconds: 0.0,
            cost_usd: Some(0.0),
        };
        for entry in entries
            .iter()
            .filter(|entry| entry.timestamp >= start && entry.timestamp <= now)
        {
            result.dictations += 1;
            result.audio_seconds += entry.audio_seconds;
            result.cost_usd = result
                .cost_usd
                .zip(cost(entry, &prices))
                .map(|(sum, cost)| sum + cost);
        }
        result
    })
}

pub fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}

pub fn bounds(now: i64) -> Bounds {
    let time = now as libc::time_t;
    // SAFETY: both pointers refer to correctly sized initialized local values.
    let mut local: libc::tm = unsafe { std::mem::zeroed() };
    unsafe { libc::localtime_r(&time, &mut local) };
    let day = local.tm_mday;
    local.tm_hour = 0;
    local.tm_min = 0;
    local.tm_sec = 0;
    local.tm_isdst = -1;
    let stamp = |mut date: libc::tm| {
        date.tm_isdst = -1;
        unsafe { libc::mktime(&mut date) as i64 }
    };
    let today = stamp(local);
    let mut week = local;
    week.tm_mday -= 6;
    let mut month = local;
    month.tm_mday = 1;
    let mut retention = local;
    retention.tm_mon -= 13;
    retention.tm_mday = 1;
    // Normalize the target month, then clamp the original day to its last day.
    let retention_time = stamp(retention) as libc::time_t;
    unsafe { libc::localtime_r(&retention_time, &mut retention) };
    let mut last = retention;
    last.tm_mon += 1;
    last.tm_mday = 0;
    let last_time = stamp(last) as libc::time_t;
    unsafe { libc::localtime_r(&last_time, &mut last) };
    retention.tm_mday = day.min(last.tm_mday);
    // Retention is measured at the same local time of day as now.
    let mut original: libc::tm = unsafe { std::mem::zeroed() };
    unsafe { libc::localtime_r(&time, &mut original) };
    retention.tm_hour = original.tm_hour;
    retention.tm_min = original.tm_min;
    retention.tm_sec = original.tm_sec;
    Bounds {
        today,
        week: stamp(week),
        month: stamp(month),
        retention: stamp(retention),
    }
}

fn error() -> String {
    crate::tr!(
        "Verbrauchszähler nicht lesbar oder schreibbar.",
        "Usage ledger could not be read or written."
    )
}

fn lock(path: &Path) -> Result<File, String> {
    let lock = OpenOptions::new()
        .create(true)
        .truncate(false)
        .write(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path.with_extension("lock"))
        .map_err(|_| error())?;
    if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX) } != 0 {
        return Err(error());
    }
    Ok(lock)
}

fn read(path: &Path) -> Result<Vec<Entry>, String> {
    let file = match OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path)
    {
        Ok(file) => file,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(_) => return Err(error()),
    };
    let mut data = Vec::new();
    file.take(16 * 1024 * 1024 + 1)
        .read_to_end(&mut data)
        .map_err(|_| error())?;
    if data.len() > 16 * 1024 * 1024 {
        return Err(error());
    }
    let entries: Vec<Entry> = serde_json::from_slice(&data).map_err(|_| error())?;
    if entries.iter().any(|entry| {
        !entry.audio_seconds.is_finite()
            || entry.audio_seconds < 0.0
            || entry.audio_seconds > 3600.0
    }) {
        return Err(error());
    }
    Ok(entries)
}

fn write(path: &Path, entries: &[Entry]) -> Result<(), String> {
    let temporary = path.with_extension(format!("{}.tmp", std::process::id()));
    let mut created = false;
    let result = (|| {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temporary)
            .map_err(|_| error())?;
        created = true;
        serde_json::to_writer(&mut file, entries).map_err(|_| error())?;
        file.flush()
            .and_then(|_| file.sync_all())
            .map_err(|_| error())?;
        fs::rename(&temporary, path).map_err(|_| error())
    })();
    if result.is_err() && created {
        let _ = fs::remove_file(temporary);
    }
    result
}

pub fn append(path: &Path, entry: Entry, bounds: Bounds) -> Result<(), String> {
    let _lock = lock(path)?;
    let mut entries = read(path)?;
    entries.retain(|entry| entry.timestamp >= bounds.retention);
    entries.push(entry);
    write(path, &entries)
}

pub fn record(
    audio: &[u8],
    server: &crate::server::Server,
    settings: &crate::settings::Settings,
    translation: Option<Translation>,
) -> Result<(), String> {
    let wave = hound::WavReader::new(std::io::Cursor::new(audio)).map_err(|_| error())?;
    if wave.spec().sample_rate == 0 {
        return Err(error());
    }
    let now = now();
    let entry = Entry {
        timestamp: now,
        custom: server.is_custom(),
        model: settings.model.clone(),
        audio_seconds: f64::from(wave.duration()) / f64::from(wave.spec().sample_rate),
        translation,
    };
    append(
        &crate::paths::state_dir()
            .map_err(crate::path_error)?
            .join("usage.json"),
        entry,
        bounds(now),
    )
}

pub fn show(reset: bool) -> Result<(), String> {
    let path = crate::paths::state_dir()
        .map_err(crate::path_error)?
        .join("usage.json");
    let _lock = lock(&path)?;
    if reset {
        write(&path, &[])?;
        return Ok(());
    }
    let now = now();
    let bounds = bounds(now);
    let mut entries = read(&path)?;
    let before = entries.len();
    entries.retain(|entry| entry.timestamp >= bounds.retention);
    if before != entries.len() {
        write(&path, &entries)?;
    }
    println!(
        "{}",
        crate::tr!(
            "Lokale Schätzung in USD; kein Kontostand.",
            "Local USD estimate; not an account balance."
        )
    );
    for (label, total) in [
        crate::i18n::t("Heute", "Today"),
        crate::i18n::t("Letzte 7 Tage", "Last 7 days"),
        crate::i18n::t("Dieser Monat", "This month"),
    ]
    .into_iter()
    .zip(totals(&entries, now, bounds))
    {
        println!(
            "{}",
            crate::tr!(
                "{label}: {} Diktate, {:.2} Minuten, {}",
                "{label}: {} dictations, {:.2} minutes, {}",
                total.dictations,
                total.audio_seconds / 60.0,
                total
                    .cost_usd
                    .map(|cost| format!("ca. ${cost:.4}"))
                    .unwrap_or_else(|| crate::tr!("Kosten unbekannt", "Cost unknown"))
            )
        );
    }
    Ok(())
}

pub fn tooltip() -> Result<String, String> {
    let path = crate::paths::state_dir()
        .map_err(crate::path_error)?
        .join("usage.json");
    let _lock = lock(&path)?;
    let now = now();
    let window = bounds(now);
    let mut entries = read(&path)?;
    let before = entries.len();
    entries.retain(|entry| entry.timestamp >= window.retention);
    if before != entries.len() {
        write(&path, &entries)?;
    }
    let total = &totals(&entries, now, window)[0];
    Ok(crate::tr!(
        "Heute: {} Diktate, {}",
        "Today: {} dictations, {}",
        total.dictations,
        total
            .cost_usd
            .map(|cost| format!("ca. {:.2} US-ct", cost * 100.0))
            .unwrap_or_else(|| crate::tr!("Kosten unbekannt", "Cost unknown"))
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shared_examples_include_unknown_custom_and_window_edges() {
        let case: serde_json::Value =
            serde_json::from_str(include_str!("../../fixtures/pricing/examples.json")).unwrap();
        let entries: Vec<Entry> = serde_json::from_value(case["entries"].clone()).unwrap();
        let bounds: Bounds = serde_json::from_value(case["bounds"].clone()).unwrap();
        for (actual, expected) in totals(&entries, case["now"].as_i64().unwrap(), bounds)
            .iter()
            .zip(case["expected"].as_array().unwrap())
        {
            assert_eq!(
                actual.dictations as u64,
                expected["dictations"].as_u64().unwrap()
            );
            assert_eq!(
                actual.audio_seconds,
                expected["audio_seconds"].as_f64().unwrap()
            );
            match expected["cost_usd"].as_f64() {
                Some(value) => assert!((actual.cost_usd.unwrap() - value).abs() < 1e-12),
                None => assert!(actual.cost_usd.is_none()),
            }
        }
        let mut missing = entries[0].clone();
        missing.translation = Some(Translation {
            model: "gpt-5.4-mini".to_string(),
            input_tokens: None,
            output_tokens: None,
        });
        assert!(cost(&missing, &prices()).is_none());
        let dir = crate::test_support::unique_temp_dir("usage");
        let path = dir.join("usage.json");
        for entry in entries {
            append(&path, entry, bounds).unwrap();
        }
        assert!(read(&path)
            .unwrap()
            .iter()
            .all(|entry| entry.timestamp >= bounds.retention));
        write(&path, &[]).unwrap();
        assert!(read(&path).unwrap().is_empty());
        let temporary = path.with_extension(format!("{}.tmp", std::process::id()));
        fs::write(&temporary, b"pre-existing file").unwrap();
        let before = fs::read(&path).unwrap();
        assert!(write(&path, &[]).is_err());
        assert_eq!(fs::read(&temporary).unwrap(), b"pre-existing file");
        assert_eq!(fs::read(&path).unwrap(), before);
        let _ = fs::remove_dir_all(dir);
    }
}
