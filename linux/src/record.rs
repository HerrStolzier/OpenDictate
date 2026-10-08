use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use hound::{SampleFormat, WavSpec, WavWriter};

pub const MAX_RECORDING: Duration = Duration::from_secs(90);
pub const MINIMUM_RECORDING: Duration = Duration::from_secs(1);
pub const SILENCE_THRESHOLD_DB: f64 = -45.0;
pub const SILENCE_PADDING: Duration = Duration::from_millis(250);
const MINIMUM_TRIM_SAVING: Duration = Duration::from_millis(350);

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

#[derive(Debug)]
pub struct PreparedAudio {
    path: PathBuf,
    temporary: bool,
}

impl PreparedAudio {
    pub fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for PreparedAudio {
    fn drop(&mut self) {
        if self.temporary {
            let _ = std::fs::remove_file(&self.path);
        }
    }
}

pub fn prepare_for_upload(path: &Path) -> Result<PreparedAudio, String> {
    let mut reader = hound::WavReader::open(path).map_err(|_| {
        crate::tr!(
            "Aufnahme konnte nicht analysiert werden.",
            "Recording could not be analysed."
        )
    })?;
    let spec = reader.spec();
    if spec.sample_format != SampleFormat::Int || spec.bits_per_sample != 16 || spec.channels == 0 {
        return Err(crate::tr!(
            "Aufnahmeformat wird nicht unterstützt.",
            "Recording format is not supported."
        ));
    }
    let samples = reader
        .samples::<i16>()
        .collect::<Result<Vec<_>, _>>()
        .map_err(|_| {
            crate::tr!(
                "Aufnahme konnte nicht analysiert werden.",
                "Recording could not be analysed."
            )
        })?;
    let channels = usize::from(spec.channels);
    let total_frames = samples.len() / channels;
    let duration = Duration::from_secs_f64(total_frames as f64 / f64::from(spec.sample_rate));
    if duration < MINIMUM_RECORDING {
        return Err(crate::tr!(
            "Aufnahme ist kürzer als 1,0 Sekunden und wurde nicht hochgeladen.",
            "Recording is shorter than 1.0 seconds and was not uploaded."
        ));
    }
    let window_frames = ((f64::from(spec.sample_rate) * 0.05).round() as usize).max(1);
    let mut first_speech = None;
    let mut last_speech = None;
    for start in (0..total_frames).step_by(window_frames) {
        let end = (start + window_frames).min(total_frames);
        let mut sum_squares = 0.0f64;
        let mut count = 0usize;
        for sample in &samples[start * channels..end * channels] {
            let normalized = f64::from(*sample) / 32768.0;
            sum_squares += normalized * normalized;
            count += 1;
        }
        let rms = if count == 0 {
            0.0
        } else {
            (sum_squares / count as f64).sqrt()
        };
        let db = 20.0 * rms.max(0.000_000_1).log10();
        if db >= SILENCE_THRESHOLD_DB {
            first_speech.get_or_insert(start);
            last_speech = Some(end);
        }
    }
    let (first_speech, last_speech) = first_speech.zip(last_speech).ok_or_else(|| {
        crate::tr!(
            "Keine Sprache erkannt; Aufnahme wurde nicht hochgeladen.",
            "No speech detected; the recording was not uploaded."
        )
    })?;
    let padding_frames = (SILENCE_PADDING.as_secs_f64() * f64::from(spec.sample_rate)) as usize;
    let start_frame = first_speech.saturating_sub(padding_frames);
    let end_frame = (last_speech + padding_frames).min(total_frames);
    let upload_frames = end_frame.saturating_sub(start_frame);
    let upload_duration =
        Duration::from_secs_f64(upload_frames as f64 / f64::from(spec.sample_rate));
    if upload_duration < MINIMUM_RECORDING {
        return Err(crate::tr!(
            "Sprachabschnitt ist kürzer als 1,0 Sekunden und wurde nicht hochgeladen.",
            "Speech is shorter than 1.0 seconds and was not uploaded."
        ));
    }
    let saving = duration.saturating_sub(upload_duration);
    if saving < MINIMUM_TRIM_SAVING {
        return Ok(PreparedAudio {
            path: path.to_path_buf(),
            temporary: false,
        });
    }
    let output = path.with_extension("upload.wav");
    let write_result = (|| {
        let mut writer = WavWriter::create(&output, spec).map_err(|_| {
            crate::tr!(
                "Vorbereitete Aufnahme konnte nicht gespeichert werden.",
                "Prepared recording could not be saved."
            )
        })?;
        for sample in &samples[start_frame * channels..end_frame * channels] {
            writer.write_sample(*sample).map_err(|_| {
                crate::tr!(
                    "Vorbereitete Aufnahme konnte nicht gespeichert werden.",
                    "Prepared recording could not be saved."
                )
            })?;
        }
        writer.finalize().map_err(|_| {
            crate::tr!(
                "Vorbereitete Aufnahme konnte nicht gespeichert werden.",
                "Prepared recording could not be saved."
            )
        })
    })();
    if let Err(error) = write_result {
        let _ = std::fs::remove_file(&output);
        return Err(error);
    }
    Ok(PreparedAudio {
        path: output,
        temporary: true,
    })
}

pub fn start(path: &Path) -> Result<RecordingHandle, String> {
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .ok_or_else(|| crate::tr!("Kein Mikrofon gefunden.", "No microphone found."))?;
    let config = device
        .default_input_config()
        .map_err(|_| crate::tr!("Mikrofon nicht verfügbar.", "Microphone unavailable."))?;
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
        _ => {
            return Err(crate::tr!(
                "Mikrofon-Sampleformat wird nicht unterstützt.",
                "Microphone sample format is not supported."
            ))
        }
    }
    .map_err(|_| {
        crate::tr!(
            "Aufnahme konnte nicht starten.",
            "Recording could not start."
        )
    })?;
    stream.play().map_err(|_| {
        crate::tr!(
            "Aufnahme konnte nicht starten.",
            "Recording could not start."
        )
    })?;
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
        let mut capture = self.capture.lock().map_err(|_| {
            crate::tr!(
                "Aufnahme konnte nicht beendet werden.",
                "Recording could not be stopped."
            )
        })?;
        if let Some(error) = capture.error.take() {
            return Err(error);
        }
        let frames = capture.frames;
        let writer = capture.writer.take().ok_or_else(|| {
            crate::tr!(
                "Aufnahme konnte nicht beendet werden.",
                "Recording could not be stopped."
            )
        })?;
        writer.finalize().map_err(|_| {
            crate::tr!(
                "Aufnahme konnte nicht gespeichert werden.",
                "Recording could not be saved."
            )
        })?;
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
        guard.error = Some(crate::tr!(
            "Aufnahme unterbrochen.",
            "Recording interrupted."
        ));
        let _ = error;
    }
}

fn io_error() -> String {
    crate::tr!(
        "Aufnahme konnte nicht gespeichert werden.",
        "Recording could not be saved."
    )
}

fn write_error() -> String {
    crate::tr!(
        "Aufnahme konnte nicht gespeichert werden.",
        "Recording could not be saved."
    )
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
    fn short_and_silent_recordings_are_not_uploadable() {
        let short =
            std::env::temp_dir().join(format!("opendictate-short-{}.wav", std::process::id()));
        write_silence_fixture(&short, 16_000, 8_000).unwrap();
        assert!(prepare_for_upload(&short).unwrap_err().contains("kürzer"));
        let silent =
            std::env::temp_dir().join(format!("opendictate-silent-{}.wav", std::process::id()));
        write_silence_fixture(&silent, 16_000, 32_000).unwrap();
        assert!(prepare_for_upload(&silent)
            .unwrap_err()
            .contains("Keine Sprache"));
        let _ = std::fs::remove_file(short);
        let _ = std::fs::remove_file(silent);
    }

    #[test]
    fn speech_is_padded_and_trimmed_when_saving_is_material() {
        let path =
            std::env::temp_dir().join(format!("opendictate-speech-{}.wav", std::process::id()));
        let spec = WavSpec {
            channels: 1,
            sample_rate: 16_000,
            bits_per_sample: 16,
            sample_format: SampleFormat::Int,
        };
        let mut writer = WavWriter::create(&path, spec).unwrap();
        for frame in 0..48_000 {
            let sample = if (16_000..32_000).contains(&frame) {
                8_000i16
            } else {
                0i16
            };
            writer.write_sample(sample).unwrap();
        }
        writer.finalize().unwrap();
        let prepared = prepare_for_upload(&path).unwrap();
        assert_ne!(prepared.path(), path);
        let reader = hound::WavReader::open(prepared.path()).unwrap();
        assert_eq!(reader.duration(), 24_000);
        drop(prepared);
        assert!(!path.with_extension("upload.wav").exists());
        let _ = std::fs::remove_file(path);
    }
}
