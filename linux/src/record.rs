use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use hound::{SampleFormat, WavSpec, WavWriter};

pub const MAX_RECORDING: Duration = Duration::from_secs(90);
/// How long the worker may take to open the microphone before it gives up;
/// `toggle` waits a little longer than this.
pub const START_TIMEOUT: Duration = Duration::from_secs(5);
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

/// Why a recording could not be ended normally, and whether its file was
/// completed with the audio captured so far.
#[derive(Debug)]
pub struct StopError {
    pub message: String,
    pub complete: bool,
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

/// What a stopped recording yields for the provider.
#[derive(Debug)]
pub enum Upload {
    Ready(PreparedAudio),
    /// Too short or without speech: nothing is sent, and the recording is
    /// kept with a mark that plain `retry` passes over. Holds the message
    /// for the user.
    Skipped(String),
}

pub fn prepare_for_upload(path: &Path) -> Result<Upload, String> {
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
        return Ok(Upload::Skipped(crate::tr!(
            "Zu kurz (unter 1 Sekunde) – nichts gesendet.",
            "Too short (under 1 second) – nothing sent."
        )));
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
    let Some((first_speech, last_speech)) = first_speech.zip(last_speech) else {
        return Ok(Upload::Skipped(crate::tr!(
            "Keine Sprache gehört – nichts gesendet.",
            "No speech heard – nothing sent."
        )));
    };
    let padding_frames = (SILENCE_PADDING.as_secs_f64() * f64::from(spec.sample_rate)) as usize;
    let start_frame = first_speech.saturating_sub(padding_frames);
    let end_frame = (last_speech + padding_frames).min(total_frames);
    let upload_frames = end_frame.saturating_sub(start_frame);
    let upload_duration =
        Duration::from_secs_f64(upload_frames as f64 / f64::from(spec.sample_rate));
    if upload_duration < MINIMUM_RECORDING {
        return Ok(Upload::Skipped(crate::tr!(
            "Zu wenig Sprache (unter 1 Sekunde) – nichts gesendet.",
            "Too little speech (under 1 second) – nothing sent."
        )));
    }
    let saving = duration.saturating_sub(upload_duration);
    if saving < MINIMUM_TRIM_SAVING {
        return Ok(Upload::Ready(PreparedAudio {
            path: path.to_path_buf(),
            temporary: false,
        }));
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
    Ok(Upload::Ready(PreparedAudio {
        path: output,
        temporary: true,
    }))
}

pub fn start(path: &Path) -> Result<RecordingHandle, String> {
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .ok_or_else(|| crate::tr!("Kein Mikrofon gefunden.", "No microphone found."))?;
    let config = device
        .default_input_config()
        .map_err(|_| crate::tr!("Mikrofon nicht verfügbar.", "Microphone unavailable."))?;
    let sample_rate = config.sample_rate();
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
    let stream = match open_stream(&device, config, &capture) {
        Ok(stream) => stream,
        Err(error) => {
            discard_if_silent(&capture, path);
            return Err(error);
        }
    };
    Ok(RecordingHandle {
        stream,
        capture,
        path: path.to_path_buf(),
        sample_rate,
    })
}

/// Opens and starts the input stream that feeds `capture`.
fn open_stream(
    device: &cpal::Device,
    config: cpal::SupportedStreamConfig,
    capture: &Arc<Mutex<Capture>>,
) -> Result<cpal::Stream, String> {
    let stream_config = config.config();
    // cpal 0.18 ranks F64 and 24/32-bit integers above I16 when choosing the
    // default config, so devices without F32 that used to record as I16 now
    // offer one of those; they are converted to the same 16-bit mono WAV.
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => build(device, stream_config, capture, write_f32),
        cpal::SampleFormat::I16 => build(device, stream_config, capture, write_i16),
        cpal::SampleFormat::U16 => build(device, stream_config, capture, write_u16),
        cpal::SampleFormat::F64 => build(device, stream_config, capture, write_converted::<f64>),
        cpal::SampleFormat::I32 => build(device, stream_config, capture, write_converted::<i32>),
        cpal::SampleFormat::U32 => build(device, stream_config, capture, write_converted::<u32>),
        cpal::SampleFormat::I24 => {
            build(device, stream_config, capture, write_converted::<cpal::I24>)
        }
        cpal::SampleFormat::U24 => {
            build(device, stream_config, capture, write_converted::<cpal::U24>)
        }
        _ => {
            return Err(crate::tr!(
                "Mikrofon-Sampleformat wird nicht unterstützt.",
                "Microphone sample format is not supported."
            ))
        }
    }
    .map_err(|error| start_failed("build", &error))?;
    stream
        .play()
        .map_err(|error| start_failed("play", &error))?;
    Ok(stream)
}

fn build<T: cpal::SizedSample + 'static>(
    device: &cpal::Device,
    config: cpal::StreamConfig,
    capture: &Arc<Mutex<Capture>>,
    write: fn(&Arc<Mutex<Capture>>, &[T]),
) -> Result<cpal::Stream, cpal::Error> {
    let stream_capture = Arc::clone(capture);
    let err_capture = Arc::clone(capture);
    device.build_input_stream(
        config,
        move |data: &[T], _| write(&stream_capture, data),
        move |error| set_error(&err_capture, error),
        None,
    )
}

/// Notes the audio backend's reason in the worker log (its stderr), which
/// never holds audio or text, and returns the user-facing message.
fn start_failed(step: &str, error: &dyn std::fmt::Display) -> String {
    eprintln!("recording-start-failed step={step} error={error}");
    crate::tr!(
        "Aufnahme konnte nicht starten. Ist ein Mikrofon angeschlossen und als Eingang gewählt?",
        "Recording could not start. Is a microphone connected and selected as input?"
    )
}

/// A recording that failed to start holds no audio, only the WAV header;
/// it is removed so it does not linger in pending. Captured audio is kept.
fn discard_if_silent(capture: &Arc<Mutex<Capture>>, path: &Path) {
    let Ok(mut guard) = capture.lock() else {
        return;
    };
    if guard.frames == 0 && guard.error.is_none() {
        drop(guard.writer.take());
        let _ = std::fs::remove_file(path);
    }
}

impl RecordingHandle {
    /// Stops a recording that is not used. Without audio it is removed and
    /// this returns `None`. Otherwise, and after any capture error, it stays
    /// and this returns whether the file was completed so it can be secured
    /// for retry.
    pub fn abort(self) -> Option<bool> {
        drop(self.stream);
        let Ok(mut capture) = self.capture.lock() else {
            return Some(false);
        };
        let writer = capture.writer.take();
        if capture.frames == 0 {
            drop(writer);
            // After an error the count can miss samples already in the file,
            // so it stays in pending, but is not offered for retry.
            if capture.error.is_some() {
                return Some(false);
            }
            let _ = std::fs::remove_file(&self.path);
            return None;
        }
        Some(writer.is_some_and(|writer| writer.finalize().is_ok()))
    }

    /// Ends the recording for processing. After a capture error (such as a
    /// microphone that was unplugged) the audio up to that point is completed
    /// when possible, so the caller can secure it for `retry`.
    pub fn stop(self) -> Result<Recording, StopError> {
        drop(self.stream);
        let frames = finish(&self.capture)?;
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

/// Completes the file of a stopped capture and returns its frame count.
fn finish(capture: &Mutex<Capture>) -> Result<u64, StopError> {
    let mut capture = capture.lock().map_err(|_| StopError {
        message: crate::tr!(
            "Aufnahme konnte nicht beendet werden.",
            "Recording could not be stopped."
        ),
        complete: false,
    })?;
    let frames = capture.frames;
    let writer = capture.writer.take();
    if let Some(message) = capture.error.take() {
        // Without counted audio the file may still miss samples, so it is not
        // completed and stays where it is, as in `abort`.
        let complete = frames > 0 && writer.is_some_and(|writer| writer.finalize().is_ok());
        return Err(StopError { message, complete });
    }
    if !writer.is_some_and(|writer| writer.finalize().is_ok()) {
        return Err(StopError {
            message: crate::tr!(
                "Aufnahme konnte nicht gespeichert werden.",
                "Recording could not be saved."
            ),
            complete: false,
        });
    }
    Ok(frames)
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

fn write_converted<T: Copy>(capture: &Arc<Mutex<Capture>>, data: &[T])
where
    i16: cpal::FromSample<T>,
{
    write_samples(
        capture,
        data.iter().copied(),
        cpal::FromSample::from_sample_,
    );
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

fn set_error(capture: &Arc<Mutex<Capture>>, error: cpal::Error) {
    // cpal 0.18 reports ALSA overruns and then recovers from them itself, so
    // they no longer end the recording (0.15 stopped capturing on most of
    // them). Up to about one period of audio can be missing at that point. A
    // failed recovery is reported as a separate error.
    if error.kind() == cpal::ErrorKind::Xrun {
        return;
    }
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
    fn only_unrecovered_stream_errors_interrupt_the_recording() {
        let capture = Arc::new(Mutex::new(Capture {
            writer: None,
            frames: 0,
            channels: 1,
            error: None,
        }));
        set_error(&capture, cpal::ErrorKind::Xrun.into());
        assert!(capture.lock().unwrap().error.is_none());
        set_error(&capture, cpal::ErrorKind::DeviceNotAvailable.into());
        assert!(capture.lock().unwrap().error.is_some());
    }

    #[test]
    fn a_failed_start_removes_only_an_empty_file() {
        let spec = WavSpec {
            channels: 1,
            sample_rate: 16_000,
            bits_per_sample: 16,
            sample_format: SampleFormat::Int,
        };
        for (frames, kept) in [(0, false), (1, true)] {
            let path = std::env::temp_dir().join(format!(
                "opendictate-failed-start-{}-{frames}.wav",
                std::process::id()
            ));
            let mut writer = WavWriter::create(&path, spec).unwrap();
            for _ in 0..frames {
                writer.write_sample(0i16).unwrap();
            }
            let capture = Arc::new(Mutex::new(Capture {
                writer: Some(writer),
                frames,
                channels: 1,
                error: None,
            }));
            discard_if_silent(&capture, &path);
            assert_eq!(path.exists(), kept);
            drop(capture);
            let _ = std::fs::remove_file(&path);
        }
    }

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
        assert!(skipped(&short).contains("Zu kurz"));
        let silent =
            std::env::temp_dir().join(format!("opendictate-silent-{}.wav", std::process::id()));
        write_silence_fixture(&silent, 16_000, 32_000).unwrap();
        assert!(skipped(&silent).contains("Keine Sprache"));
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
        let Upload::Ready(prepared) = prepare_for_upload(&path).unwrap() else {
            panic!("speech was skipped");
        };
        assert_ne!(prepared.path(), path);
        let reader = hound::WavReader::open(prepared.path()).unwrap();
        assert_eq!(reader.duration(), 24_000);
        drop(prepared);
        assert!(!path.with_extension("upload.wav").exists());
        let _ = std::fs::remove_file(path);
    }

    fn skipped(path: &Path) -> String {
        match prepare_for_upload(path).unwrap() {
            Upload::Skipped(message) => message,
            Upload::Ready(_) => panic!("recording was not skipped"),
        }
    }

    fn capture_into(path: &Path, channels: u16) -> Arc<Mutex<Capture>> {
        let spec = WavSpec {
            channels: 1,
            sample_rate: 16_000,
            bits_per_sample: 16,
            sample_format: SampleFormat::Int,
        };
        Arc::new(Mutex::new(Capture {
            writer: Some(WavWriter::create(path, spec).unwrap()),
            frames: 0,
            channels,
            error: None,
        }))
    }

    fn written(capture: &Arc<Mutex<Capture>>, path: &Path) -> Vec<i16> {
        finish(capture).unwrap();
        hound::WavReader::open(path)
            .unwrap()
            .samples::<i16>()
            .collect::<Result<_, _>>()
            .unwrap()
    }

    fn temp_wav(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("opendictate-{name}-{}.wav", std::process::id()))
    }

    #[test]
    fn stereo_is_averaged_to_mono_and_a_partial_frame_is_dropped() {
        let path = temp_wav("downmix");
        let capture = capture_into(&path, 2);
        write_i16(&capture, &[100, 300, -200, -400, i16::MAX, i16::MAX, 7]);
        assert_eq!(capture.lock().unwrap().frames, 3);
        assert_eq!(written(&capture, &path), [200, -300, i16::MAX]);
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn float_samples_are_scaled_and_clipped() {
        let path = temp_wav("float");
        let capture = capture_into(&path, 1);
        write_f32(&capture, &[0.0, 0.5, 1.0, -1.0, 2.0, -2.0]);
        assert_eq!(
            written(&capture, &path),
            [0, 16_384, i16::MAX, -i16::MAX, i16::MAX, i16::MIN]
        );
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn unsigned_samples_are_centred_on_zero() {
        let path = temp_wav("unsigned");
        let capture = capture_into(&path, 1);
        write_u16(&capture, &[0, 32_768, u16::MAX]);
        assert_eq!(written(&capture, &path), [i16::MIN, 0, i16::MAX]);
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn wider_formats_keep_silence_and_full_scale() {
        let path = temp_wav("converted");
        let capture = capture_into(&path, 1);
        write_converted(&capture, &[0i32, i32::MAX, i32::MIN]);
        write_converted(&capture, &[0.0f64, 1.0, -1.0]);
        write_converted(&capture, &[u32::MAX / 2 + 1, u32::MAX, 0]);
        let samples = written(&capture, &path);
        for chunk in samples.chunks(3) {
            assert_eq!(chunk[0], 0);
            assert!(chunk[1] >= i16::MAX - 1, "{chunk:?}");
            assert!(chunk[2] <= i16::MIN + 1, "{chunk:?}");
        }
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn an_interrupted_recording_keeps_the_audio_captured_so_far() {
        let path = temp_wav("interrupted");
        let capture = capture_into(&path, 1);
        write_i16(&capture, &[1, 2, 3]);
        set_error(&capture, cpal::ErrorKind::DeviceNotAvailable.into());
        let error = finish(&capture).unwrap_err();
        assert!(error.complete);
        assert!(error.message.contains("unterbrochen"));
        let reader = hound::WavReader::open(&path).unwrap();
        assert_eq!(reader.duration(), 3);
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn an_interrupted_recording_without_counted_audio_is_not_complete() {
        let path = temp_wav("interrupted-empty");
        let capture = capture_into(&path, 1);
        set_error(&capture, cpal::ErrorKind::DeviceNotAvailable.into());
        assert!(!finish(&capture).unwrap_err().complete);
        let _ = std::fs::remove_file(path);
    }
}
