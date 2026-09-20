use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use hound::{SampleFormat, WavSpec, WavWriter};

pub const MAX_RECORDING: Duration = Duration::from_secs(90);

struct Capture {
    writer: Option<WavWriter<std::io::BufWriter<std::fs::File>>>,
    frames: u64,
    channels: u16,
    error: Option<String>,
}

pub struct Recording {
    pub path: PathBuf,
    pub duration: Duration,
}

pub struct RecordingHandle {
    stream: cpal::Stream,
    capture: Arc<Mutex<Capture>>,
    path: PathBuf,
    sample_rate: u32,
}

pub fn start(path: &Path) -> Result<RecordingHandle, String> {
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .ok_or_else(|| "Kein Mikrofon gefunden.".to_string())?;
    let config = device
        .default_input_config()
        .map_err(|_| "Mikrofon nicht verfügbar.".to_string())?;
    let sample_rate = config.sample_rate().0;
    let channels = config.channels();
    let spec = WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: SampleFormat::Int,
    };
    let writer = WavWriter::create(path, spec).map_err(|_| io_error())?;
    let capture = Arc::new(Mutex::new(Capture {
        writer: Some(writer),
        frames: 0,
        channels,
        error: None,
    }));
    let stream_capture = Arc::clone(&capture);
    let err_capture = Arc::clone(&capture);
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _| write_f32(&stream_capture, data),
            move |error| set_error(&err_capture, error),
            None,
        ),
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _| write_i16(&stream_capture, data),
            move |error| set_error(&err_capture, error),
            None,
        ),
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _| write_u16(&stream_capture, data),
            move |error| set_error(&err_capture, error),
            None,
        ),
        _ => return Err("Mikrofon-Sampleformat wird nicht unterstützt.".to_string()),
    }
    .map_err(|_| "Aufnahme konnte nicht starten.".to_string())?;
    stream
        .play()
        .map_err(|_| "Aufnahme konnte nicht starten.".to_string())?;
    Ok(RecordingHandle {
        stream,
        capture,
        path: path.to_path_buf(),
        sample_rate,
    })
}

impl RecordingHandle {
    pub fn stop(self) -> Result<Recording, String> {
        drop(self.stream);
        let mut capture = self
            .capture
            .lock()
            .map_err(|_| "Aufnahme konnte nicht beendet werden.".to_string())?;
        if let Some(error) = capture.error.take() {
            return Err(error);
        }
        let frames = capture.frames;
        let writer = capture
            .writer
            .take()
            .ok_or_else(|| "Aufnahme konnte nicht beendet werden.".to_string())?;
        writer
            .finalize()
            .map_err(|_| "Aufnahme konnte nicht gespeichert werden.".to_string())?;
        let duration = if self.sample_rate == 0 {
            Duration::ZERO
        } else {
            Duration::from_secs_f64(frames as f64 / f64::from(self.sample_rate))
        };
        Ok(Recording {
            path: self.path,
            duration,
        })
    }
}

fn write_f32(capture: &Arc<Mutex<Capture>>, data: &[f32]) {
    write_samples(capture, data.iter().copied(), clamp_i16);
}

fn write_i16(capture: &Arc<Mutex<Capture>>, data: &[i16]) {
    write_samples(capture, data.iter().copied(), |sample| sample);
}

fn write_u16(capture: &Arc<Mutex<Capture>>, data: &[u16]) {
    write_samples(capture, data.iter().copied(), |sample| {
        (i32::from(sample) - 32768) as i16
    });
}

fn write_samples<T, F>(
    capture: &Arc<Mutex<Capture>>,
    samples: impl IntoIterator<Item = T>,
    convert: F,
) where
    F: Fn(T) -> i16,
{
    let Ok(mut guard) = capture.lock() else {
        return;
    };
    let channels = guard.channels.max(1) as usize;
    let Some(writer) = guard.writer.as_mut() else {
        return;
    };
    match write_downmixed(writer, channels, samples, convert) {
        Ok(frames) => guard.frames += frames,
        Err(error) => guard.error = Some(error),
    }
}

fn write_downmixed<T, F>(
    writer: &mut WavWriter<std::io::BufWriter<std::fs::File>>,
    channels: usize,
    samples: impl IntoIterator<Item = T>,
    convert: F,
) -> Result<u64, String>
where
    F: Fn(T) -> i16,
{
    let mut frames = 0u64;
    if channels <= 1 {
        for sample in samples {
            writer
                .write_sample(convert(sample))
                .map_err(|_| write_error())?;
            frames += 1;
        }
        return Ok(frames);
    }
    let mut acc = 0i32;
    let mut index = 0usize;
    for sample in samples {
        acc += i32::from(convert(sample));
        index += 1;
        if index == channels {
            writer
                .write_sample((acc / channels as i32) as i16)
                .map_err(|_| write_error())?;
            acc = 0;
            index = 0;
            frames += 1;
        }
    }
    Ok(frames)
}

fn clamp_i16(sample: f32) -> i16 {
    let scaled = (sample * f32::from(i16::MAX)).round();
    scaled.clamp(f32::from(i16::MIN), f32::from(i16::MAX)) as i16
}

fn set_error(capture: &Arc<Mutex<Capture>>, error: cpal::StreamError) {
    if let Ok(mut guard) = capture.lock() {
        guard.error = Some("Aufnahme unterbrochen.".to_string());
        let _ = error;
    }
}

fn io_error() -> String {
    "Aufnahme konnte nicht gespeichert werden.".to_string()
}

fn write_error() -> String {
    "Aufnahme konnte nicht gespeichert werden.".to_string()
}

#[cfg(test)]
pub fn write_silence_fixture(path: &Path, sample_rate: u32, frames: u32) -> std::io::Result<()> {
    let spec = WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 16,
        sample_format: SampleFormat::Int,
    };
    let map = |error: hound::Error| std::io::Error::other(error);
    let mut writer = WavWriter::create(path, spec).map_err(map)?;
    for _ in 0..frames {
        writer.write_sample(0i16).map_err(map)?;
    }
    writer.finalize().map_err(map)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn silence_fixture_is_a_valid_wav() {
        let path =
            std::env::temp_dir().join(format!("opendictate-silence-{}.wav", std::process::id()));
        write_silence_fixture(&path, 16_000, 160).unwrap();
        let reader = hound::WavReader::open(&path).unwrap();
        assert_eq!(reader.spec().channels, 1);
        assert_eq!(reader.spec().sample_rate, 16_000);
        assert_eq!(reader.duration(), 160);
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn max_recording_matches_macos_cap() {
        assert_eq!(MAX_RECORDING, Duration::from_secs(90));
    }
}
