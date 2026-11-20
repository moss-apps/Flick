//! Audio analysis bridge: single-pass decode → waveform peaks + BS.1770
//! loudness + true peak + DR + LRA + clipping. No PCM retained — everything
//! is computed in one streaming pass and returned as small summaries.

use std::collections::VecDeque;
use std::fs::File;
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Mutex;

use realfft::num_complex::Complex;
use realfft::{RealFftPlanner, RealToComplex};
use symphonia::core::codecs::audio::{AudioDecoderOptions, CODEC_ID_NULL_AUDIO};
use symphonia::core::codecs::CodecParameters;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, FormatReader, TrackType};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::packet::Packet;

pub struct AudioAnalysisResult {
    pub peaks: Vec<f32>,
    pub lufs: Option<f64>,
    pub true_peak_db: Option<f64>,
    pub dr: Option<f64>,
    pub lra: Option<f64>,
    pub clipping: bool,
}

// ---------------------------------------------------------------------------
// Biquad filter
// ---------------------------------------------------------------------------

struct Biquad {
    b0: f64,
    b1: f64,
    b2: f64,
    a1: f64,
    a2: f64,
    z1: f64,
    z2: f64,
}

impl Biquad {
    fn new(b: [f64; 3], a: [f64; 2]) -> Self {
        Self { b0: b[0], b1: b[1], b2: b[2], a1: a[0], a2: a[1], z1: 0.0, z2: 0.0 }
    }

    #[inline]
    fn process(&mut self, x: f64) -> f64 {
        let y = self.b0 * x + self.z1;
        self.z1 = self.b1 * x - self.a1 * y + self.z2;
        self.z2 = self.b2 * x - self.a2 * y;
        y
    }
}

// BS.1770-4 K-filter coefficients (designed for 48 kHz).
// ponytail: used as-is at all sample rates; error is small at 44.1 kHz and
// increases at 88.2/96/176.4/192 kHz. Add bilinear-transform warping if
// mastering-grade accuracy is needed.
const K_S1_B: [f64; 3] = [1.53512485958697, -2.69169618940638, 1.19839281085285];
const K_S1_A: [f64; 2] = [-1.69065929318241, 0.73248077421585];
const K_S2_B: [f64; 3] = [1.0, -2.0, 1.0];
const K_S2_A: [f64; 2] = [-1.99004745483398, 0.990072250366629];

// ---------------------------------------------------------------------------
// BS.1770 gating (integrated loudness + LRA)
// ---------------------------------------------------------------------------

/// BS.1770-4 integrated loudness with absolute + relative gating.
fn integrated_loudness(block_msqs: &[f64]) -> Option<f64> {
    if block_msqs.is_empty() {
        return None;
    }
    let abs_gate = 10f64.powf((-70.0 + 0.691) / 10.0);
    let gated: Vec<f64> = block_msqs.iter().filter(|&&m| m > abs_gate).copied().collect();
    if gated.is_empty() {
        return None;
    }
    let mean = gated.iter().sum::<f64>() / gated.len() as f64;
    // Relative gate: mean − 10 LU → mean_msq / 10.
    let rel_gate = mean * 0.1;
    let rel_gated: Vec<f64> = gated.iter().filter(|&&m| m > rel_gate).copied().collect();
    if rel_gated.is_empty() {
        return None;
    }
    let final_mean = rel_gated.iter().sum::<f64>() / rel_gated.len() as f64;
    Some(-0.691 + 10.0 * final_mean.log10())
}

/// Loudness range: P95 − P10 of block loudness after absolute + relative (−20 LU) gating.
fn loudness_range(block_msqs: &[f64]) -> Option<f64> {
    if block_msqs.len() < 4 {
        return None;
    }
    let abs_gate = 10f64.powf((-70.0 + 0.691) / 10.0);
    let mut lufs_vals: Vec<f64> = block_msqs
        .iter()
        .filter(|&&m| m > abs_gate)
        .map(|&m| -0.691 + 10.0 * m.log10())
        .collect();
    if lufs_vals.len() < 4 {
        return None;
    }
    let mean = lufs_vals.iter().sum::<f64>() / lufs_vals.len() as f64;
    lufs_vals.retain(|&l| l > mean - 20.0);
    if lufs_vals.len() < 4 {
        return None;
    }
    lufs_vals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let p10 = lufs_vals[((lufs_vals.len() as f64 - 1.0) * 0.10).round() as usize];
    let p95 = lufs_vals[((lufs_vals.len() as f64 - 1.0) * 0.95).round() as usize];
    Some(p95 - p10)
}

// ---------------------------------------------------------------------------
// Main analysis
// ---------------------------------------------------------------------------

/// Decode `path` once, computing waveform peaks + BS.1770 metrics.
/// Returns `None` for unsupported/unreachable files — callers treat that as a
/// silent skip.
///
/// `peak_buckets` controls the waveform resolution (typ. 240).
pub fn analyze_audio_file(path: String, peak_buckets: u32) -> Option<AudioAnalysisResult> {
    let path_obj = Path::new(&path);

    // DSD and WavPack go through their own decoders (Phase 2.6); skip for now.
    if let Some(ext) = path_obj.extension().and_then(|e| e.to_str()) {
        match ext.to_lowercase().as_str() {
            "dsf" | "dff" | "wv" => return None,
            _ => {}
        }
    }

    let file = File::open(path_obj).ok()?;
    let mss = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(ext) = path_obj.extension().and_then(|e| e.to_str()) {
        hint.with_extension(ext);
    }

    let probed = symphonia::default::get_probe()
        .probe(
            &hint,
            mss,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .ok()?;

    let (codec_params, num_frames) = {
        let track = probed.tracks().iter().find(|t| {
            matches!(
                &t.codec_params,
                Some(CodecParameters::Audio(p)) if p.codec != CODEC_ID_NULL_AUDIO
            )
        })?;
        let params = match &track.codec_params {
            Some(CodecParameters::Audio(p)) => p.clone(),
            _ => return None,
        };
        (params, track.num_frames)
    };
    let sr = codec_params.sample_rate.unwrap_or(44100) as f64;
    let ch = codec_params
        .channels
        .as_ref()
        .map(|c| c.count())
        .unwrap_or(1)
        .min(2);

    let mut decoder = symphonia::default::get_codecs()
        .make_audio_decoder(&codec_params, &AudioDecoderOptions::default())
        .ok()?;

    let mut format_ctx = probed;

    // K-filter biquads per channel.
    let mut kfilters: Vec<[Biquad; 2]> = (0..ch)
        .map(|_| [Biquad::new(K_S1_B, K_S1_A), Biquad::new(K_S2_B, K_S2_A)])
        .collect();

    // LUFS block state: 400 ms blocks, 100 ms hop (75 % overlap).
    let block_size = (0.4 * sr) as usize;
    let hop = (0.1 * sr) as usize;
    let mut ring: VecDeque<f64> = VecDeque::with_capacity(block_size + 1);
    let mut ring_sum: f64 = 0.0;
    let mut since_hop: usize = 0;
    let mut block_msqs: Vec<f64> = Vec::new();

    // DR state: 3 s blocks, channel 0.
    let dr_block = (3.0 * sr) as usize;
    let mut dr_peak: f64 = 0.0;
    let mut dr_sq: f64 = 0.0;
    let mut dr_n: usize = 0;
    let mut dr_vals: Vec<f64> = Vec::new();

    // True peak & clipping.
    let mut tp: f64 = 0.0;
    let mut prev = vec![0.0f64; ch];
    let mut clips: u64 = 0;

    // Peaks.
    let n_buckets = peak_buckets.max(1) as usize;
    let mut bucket_max = vec![0.0f32; n_buckets];
    let mut frames_seen: u64 = 0;
    let total = num_frames
        .map(|n| n as u64)
        .unwrap_or_else(|| (sr * 600.0) as u64);
    let per_bucket = (total / n_buckets as u64).max(1);

    let mut interleaved: Vec<f32> = Vec::new();
    loop {
        let packet = match format_ctx.next_packet() {
            Ok(Some(p)) => p,
            Ok(None) => break,
            Err(_) => break,
        };

        let decoded = match decoder.decode(&packet) {
            Ok(d) => d,
            Err(_) => continue,
        };

        let buf_ch = decoded.spec().channels().count().max(1);
        decoded.copy_to_vec_interleaved::<f32>(&mut interleaved);
        let nf = decoded.frames();

        for f in 0..nf {
            let s0 = interleaved[f * buf_ch] as f64;
            let abs0 = s0.abs();

            let mut wss = 0.0;
            for c in 0..ch {
                let s = if c == 0 {
                    s0
                } else {
                    interleaved[f * buf_ch + c] as f64
                };
                let a = s.abs();

                // K-filter.
                let [ref mut s1, ref mut s2] = kfilters[c];
                let filt = s2.process(s1.process(s));
                wss += filt * filt;

                // True peak (ponytail: ×4 linear-interp approximation).
                if a > tp {
                    tp = a;
                }
                for &fr in &[0.25f64, 0.5, 0.75] {
                    let v = (prev[c] + (s - prev[c]) * fr).abs();
                    if v > tp {
                        tp = v;
                    }
                }
                prev[c] = s;

                // Clipping.
                if a >= 0.9999 {
                    clips += 1;
                }
            }

            // Peaks (channel 0).
            let bucket = ((frames_seen / per_bucket) as usize).min(n_buckets - 1);
            let a0f = abs0 as f32;
            if a0f > bucket_max[bucket] {
                bucket_max[bucket] = a0f;
            }

            // LUFS ring.
            ring_sum += wss;
            ring.push_back(wss);
            if ring.len() > block_size {
                ring_sum -= ring.pop_front().unwrap();
            }
            since_hop += 1;
            if since_hop >= hop && ring.len() >= block_size {
                block_msqs.push(ring_sum / block_size as f64);
                since_hop = 0;
            }

            // DR (channel 0).
            if abs0 > dr_peak {
                dr_peak = abs0;
            }
            dr_sq += s0 * s0;
            dr_n += 1;
            if dr_n >= dr_block {
                let rms = (dr_sq / dr_n as f64).sqrt();
                if rms > 0.0 && dr_peak > 0.0 {
                    dr_vals.push(20.0 * (dr_peak / rms).log10());
                }
                dr_peak = 0.0;
                dr_sq = 0.0;
                dr_n = 0;
            }

            frames_seen += 1;
        }
    }

    // -- Finalize peaks --
    let gmax = bucket_max.iter().cloned().fold(0.0f32, f32::max);
    let peaks: Vec<f32> = if gmax > 0.0 {
        bucket_max.iter().map(|&m| m / gmax).collect()
    } else {
        vec![0.0; n_buckets]
    };

    // -- Finalize DR: flush partial block, then top-20 % average --
    if dr_n > 0 {
        let rms = (dr_sq / dr_n as f64).sqrt();
        if rms > 0.0 && dr_peak > 0.0 {
            dr_vals.push(20.0 * (dr_peak / rms).log10());
        }
    }
    let dr = if dr_vals.is_empty() {
        None
    } else {
        dr_vals.sort_by(|a, b| b.partial_cmp(a).unwrap());
        let top = (dr_vals.len() / 5).max(1);
        Some(dr_vals[..top].iter().sum::<f64>() / top as f64)
    };

    let true_peak_db = if tp > 0.0 { Some(20.0 * tp.log10()) } else { None };
    let lufs = integrated_loudness(&block_msqs);
    let lra = loudness_range(&block_msqs);

    Some(AudioAnalysisResult {
        peaks,
        lufs,
        true_peak_db,
        dr,
        lra,
        clipping: clips > 10,
    })
}

// ---------------------------------------------------------------------------
// Source audio analysis (read-only, independent of playback and preload)
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AudioSourceAnalysisStatus {
    Ok,
    UnsupportedFormat,
    UnsupportedMultichannel,
    Unreadable,
    NoAudioStream,
    NoSamples,
    Cancelled,
    Busy,
}

pub struct AudioSourceSpectrogram {
    pub columns: u32,
    pub bins: u32,
    pub min_frequency_hz: f64,
    pub max_frequency_hz: f64,
    /// Row-major: `column * bins + bin`, bin 0 is the lowest frequency.
    pub left_db: Vec<f32>,
    /// Empty for mono sources.
    pub right_db: Vec<f32>,
}

pub struct AudioSourceAnalysis {
    pub status: AudioSourceAnalysisStatus,
    pub file_size_bytes: u64,
    pub duration_seconds: Option<f64>,
    pub sample_rate: Option<u32>,
    pub channels: Option<u32>,
    pub bit_depth: Option<u32>,
    pub channel_peak_db: Vec<f64>,
    pub channel_rms_db: Vec<f64>,
    pub balance_db: Option<f64>,
    pub side_mid_db: Option<f64>,
    pub leading_silence_seconds: Option<f64>,
    pub trailing_silence_seconds: Option<f64>,
    pub silent: bool,
    pub lufs: Option<f64>,
    pub lra: Option<f64>,
    pub true_peak_db: Option<f64>,
    pub dr: Option<f64>,
    pub clipping: bool,
    pub clipped_samples: u64,
    pub spectrogram: Option<AudioSourceSpectrogram>,
}

static SOURCE_ANALYZER: Mutex<()> = Mutex::new(());

/// One analysis request. Cancellation is sticky, even before the worker starts.
#[flutter_rust_bridge::frb(opaque)]
pub struct AudioSourceAnalysisJob {
    cancelled: AtomicBool,
    progress: AtomicU32,
}

#[flutter_rust_bridge::frb(sync)]
pub fn create_source_audio_analysis_job() -> AudioSourceAnalysisJob {
    AudioSourceAnalysisJob {
        cancelled: AtomicBool::new(false),
        progress: AtomicU32::new(0),
    }
}

impl AudioSourceAnalysisJob {
    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Relaxed);
    }

    /// Returns 0.0 when the total frame count is unknown.
    #[flutter_rust_bridge::frb(sync)]
    pub fn progress(&self) -> f64 {
        self.progress.load(Ordering::Relaxed) as f64 / ANALYSIS_PROGRESS_MAX as f64
    }

    /// Opens a separate file handle without touching playback, DSP, or tags.
    pub fn analyze(&self, path: String) -> AudioSourceAnalysis {
        if self.is_cancelled() {
            return empty_source_analysis(AudioSourceAnalysisStatus::Cancelled, 0);
        }
        let Ok(_guard) = SOURCE_ANALYZER.try_lock() else {
            return empty_source_analysis(AudioSourceAnalysisStatus::Busy, 0);
        };

        #[cfg(target_os = "android")]
        let result = std::thread::scope(|scope| {
            // Linux nice values are per thread. Don't renice a shared FRB worker.
            std::thread::Builder::new()
                .name("flick-source-analysis".into())
                .spawn_scoped(scope, || {
                    unsafe { libc::setpriority(libc::PRIO_PROCESS, 0, 10) };
                    analyze_source_audio_file_inner(&path, self)
                })
                .ok()
                .and_then(|worker| worker.join().ok())
                .unwrap_or_else(|| empty_source_analysis(AudioSourceAnalysisStatus::Unreadable, 0))
        });

        #[cfg(not(target_os = "android"))]
        let result = analyze_source_audio_file_inner(&path, self);

        if result.status == AudioSourceAnalysisStatus::Ok {
            self.progress
                .store(ANALYSIS_PROGRESS_MAX, Ordering::Relaxed);
        }
        result
    }

    fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Relaxed)
    }
}

const ANALYSIS_PROGRESS_MAX: u32 = 1000;
const SILENCE_THRESHOLD: f64 = 0.001; // −60 dBFS
const DB_FLOOR: f64 = -120.0;

const SPECTROGRAM_FFT_SIZE: usize = 2048;
const SPECTROGRAM_HOP: usize = SPECTROGRAM_FFT_SIZE / 2;
const SPECTROGRAM_BINS: usize = 192;
const SPECTROGRAM_MAX_COLUMNS: usize = 1024;
const SPECTROGRAM_MIN_HZ: f64 = 20.0;

const TP_PHASES: usize = 4;
const TP_TAPS: usize = 13;
const TP_DELAY: usize = TP_TAPS / 2;

fn empty_source_analysis(
    status: AudioSourceAnalysisStatus,
    file_size_bytes: u64,
) -> AudioSourceAnalysis {
    AudioSourceAnalysis {
        status,
        file_size_bytes,
        duration_seconds: None,
        sample_rate: None,
        channels: None,
        bit_depth: None,
        channel_peak_db: Vec::new(),
        channel_rms_db: Vec::new(),
        balance_db: None,
        side_mid_db: None,
        leading_silence_seconds: None,
        trailing_silence_seconds: None,
        silent: false,
        lufs: None,
        lra: None,
        true_peak_db: None,
        dr: None,
        clipping: false,
        clipped_samples: 0,
        spectrogram: None,
    }
}

fn amplitude_to_db(amplitude: f64) -> f64 {
    if amplitude <= 0.0 {
        DB_FLOOR
    } else {
        (20.0 * amplitude.log10()).max(DB_FLOOR)
    }
}

/// BS.1770-4 K-filter coefficients for an arbitrary sample rate.
/// Returns `(stage1_b, stage1_a, stage2_b, stage2_a)`.
fn k_filter_coefficients(sample_rate: f64) -> ([f64; 3], [f64; 2], [f64; 3], [f64; 2]) {
    let pi = std::f64::consts::PI;

    let f0 = 1681.974_450_955_533;
    let gain_db = 3.999_843_853_973_347;
    let q = 0.707_175_236_955_419_6;
    let k = (pi * f0 / sample_rate).tan();
    let vh = 10f64.powf(gain_db / 20.0);
    let vb = vh.powf(0.499_666_774_154_541_6);
    let a0 = 1.0 + k / q + k * k;
    let stage1_b = [
        (vh + vb * k / q + k * k) / a0,
        2.0 * (k * k - vh) / a0,
        (vh - vb * k / q + k * k) / a0,
    ];
    let stage1_a = [2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0];

    let f0 = 38.135_470_876_024_44;
    let q = 0.500_327_037_323_877_3;
    let k = (pi * f0 / sample_rate).tan();
    let a0 = 1.0 + k / q + k * k;
    let stage2_b = [1.0, -2.0, 1.0];
    let stage2_a = [2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0];

    (stage1_b, stage1_a, stage2_b, stage2_a)
}

/// 4× windowed-sinc interpolator with an odd 49-tap prototype. Phase zero
/// reconstructs an original sample exactly, so only the fractional phases
/// need convolution. At higher rates the input already gives finer resolution.
fn true_peak_coefficients() -> [[f64; TP_TAPS]; TP_PHASES] {
    std::array::from_fn(|phase| {
        std::array::from_fn(|tap| {
            let x = tap as f64 - TP_DELAY as f64 + phase as f64 / TP_PHASES as f64;
            let omega = std::f64::consts::PI * x;
            if x == 0.0 {
                1.0
            } else if x.abs() >= TP_DELAY as f64 {
                0.0
            } else {
                (omega.sin() / omega) * 0.5 * (1.0 + (omega / TP_DELAY as f64).cos())
            }
        })
    })
}

fn interpolated_peak(
    history: &mut [f64; TP_TAPS],
    sample: f64,
    phases: &[[f64; TP_TAPS]; TP_PHASES],
    step: usize,
) -> f64 {
    if step == TP_PHASES {
        return sample.abs();
    }
    history.rotate_right(1);
    history[0] = sample;
    phases[step..]
        .iter()
        .step_by(step)
        .map(|phase| {
            phase
                .iter()
                .zip(history.iter())
                .map(|(c, s)| c * s)
                .sum::<f64>()
                .abs()
        })
        .fold(sample.abs(), f64::max)
}

fn hann_window(len: usize) -> Vec<f64> {
    (0..len)
        .map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / (len as f64 - 1.0)).cos())
        .collect()
}

/// Map each log-spaced display row to its position in the linear FFT.
fn spectrogram_bin_positions(sample_rate: f64, fft_size: usize, bins: usize) -> Vec<f64> {
    let ratio = (sample_rate / 2.0) / SPECTROGRAM_MIN_HZ;
    (0..bins)
        .map(|bin| {
            let hz = SPECTROGRAM_MIN_HZ * ratio.powf(bin as f64 / (bins - 1) as f64);
            (hz * fft_size as f64 / sample_rate).min((fft_size / 2) as f64)
        })
        .collect()
}

fn spectrogram_column(
    samples: &VecDeque<f64>,
    fft: &dyn RealToComplex<f64>,
    fft_input: &mut [f64],
    fft_output: &mut [Complex<f64>],
    fft_scratch: &mut [Complex<f64>],
    window: &[f64],
    bin_positions: &[f64],
    column: &mut [f32],
) {
    for (i, &sample) in samples.iter().enumerate() {
        fft_input[i] = sample * window[i];
    }
    fft.process_with_scratch(fft_input, fft_output, fft_scratch)
        .expect("FFT buffers have the planned lengths");

    let scale = (4.0 / (fft.len() - 1) as f64).powi(2);
    let power = |k: usize| {
        if k == 0 {
            return 0.0;
        }
        fft_output[k].norm_sqr() * scale * if k == fft.len() / 2 { 0.25 } else { 1.0 }
    };
    for (i, (&center, slot)) in bin_positions.iter().zip(column).enumerate() {
        let left = i
            .checked_sub(1)
            .map_or(center, |j| (bin_positions[j] * center).sqrt());
        let right = bin_positions
            .get(i + 1)
            .map_or(center, |next| (next * center).sqrt());
        let start = left.ceil() as usize;
        let end = right.floor() as usize;
        let value = if start <= end {
            // Preserve narrow peaks when several FFT bins fit under one row.
            (start..=end).map(power).fold(0.0, f64::max)
        } else {
            // Interpolate where rows are narrower than the FFT resolution.
            let low = center.floor() as usize;
            let fraction = center.fract();
            power(low) * (1.0 - fraction) + power(low + 1) * fraction
        };
        *slot = slot.max(value.min(1.0) as f32);
    }
}

/// Fixed-size, equally spaced time bins. All overlapping FFT windows are
/// evaluated, even on long files. Merge with max power to retain short events.
struct SpectrumColumns {
    data: Vec<f32>,
    windows_per_column: usize,
}

impl SpectrumColumns {
    fn new() -> Self {
        Self {
            data: Vec::new(),
            windows_per_column: 1,
        }
    }
    fn column(&mut self, window_index: usize) -> &mut [f32] {
        let mut column = window_index / self.windows_per_column;
        if column == SPECTROGRAM_MAX_COLUMNS {
            for i in 0..SPECTROGRAM_MAX_COLUMNS / 2 {
                for bin in 0..SPECTROGRAM_BINS {
                    let start = i * 2 * SPECTROGRAM_BINS + bin;
                    self.data[i * SPECTROGRAM_BINS + bin] =
                        self.data[start].max(self.data[start + SPECTROGRAM_BINS]);
                }
            }
            self.data
                .truncate(SPECTROGRAM_MAX_COLUMNS / 2 * SPECTROGRAM_BINS);
            self.windows_per_column *= 2;
            column /= 2;
        }
        let offset = column * SPECTROGRAM_BINS;
        if self.data.len() <= offset {
            self.data.resize(offset + SPECTROGRAM_BINS, 0.0);
        }
        &mut self.data[offset..offset + SPECTROGRAM_BINS]
    }
}

fn power_to_db(power: f32) -> f32 {
    let db = 10.0 * (power as f64).max(1e-12).log10();
    db.clamp(DB_FLOOR, 0.0) as f32
}

// 0.1 dB bins keep memory independent of duration. Sum exact powers within
// bins; only gate boundaries and the LRA percentiles are quantized.
const LOUDNESS_HISTOGRAM_BINS: usize = 1200;

struct MeasurementHistogram {
    counts: [u64; LOUDNESS_HISTOGRAM_BINS],
    sums: [f64; LOUDNESS_HISTOGRAM_BINS],
}

impl MeasurementHistogram {
    fn new() -> Self {
        Self {
            counts: [0; LOUDNESS_HISTOGRAM_BINS],
            sums: [0.0; LOUDNESS_HISTOGRAM_BINS],
        }
    }
    fn index(level: f64) -> usize {
        (((level + 70.0) * 10.0) as usize).min(LOUDNESS_HISTOGRAM_BINS - 1)
    }
    fn record(&mut self, level: f64, value: f64) {
        let index = Self::index(level);
        self.counts[index] += 1;
        self.sums[index] += value;
    }
    fn mean_above(&self, gate: usize) -> Option<f64> {
        let count: u64 = self.counts[gate..].iter().sum();
        (count != 0).then(|| self.sums[gate..].iter().sum::<f64>() / count as f64)
    }
    fn record_energy(&mut self, energy: f64) {
        let level = -0.691 + 10.0 * energy.log10();
        if level >= -70.0 {
            self.record(level, energy);
        }
    }
    fn relative_gate(&self, relative_lu: f64) -> Option<usize> {
        let mean = self.mean_above(0)?;
        Some(Self::index(-0.691 + 10.0 * mean.log10() + relative_lu))
    }
    fn loudness_range(&self) -> Option<f64> {
        let gate = self.relative_gate(-20.0)?;
        let count: u64 = self.counts[gate..].iter().sum();
        if count < 2 {
            return None;
        }
        let percentile_bin = |p: f64| {
            let rank = ((count - 1) as f64 * p).round() as u64;
            let mut seen = 0;
            self.counts[gate..].iter().position(|&n| {
                seen += n;
                seen > rank
            })
        };
        Some((percentile_bin(0.95)? - percentile_bin(0.10)?) as f64 / 10.0)
    }
    fn mean_top_fifth(&self) -> Option<f64> {
        let count: u64 = self.counts.iter().sum();
        if count == 0 {
            return None;
        }
        let take = (count / 5).max(1);
        let mut remaining = take;
        let mut sum = 0.0;
        for (&n, &total) in self.counts.iter().zip(&self.sums).rev() {
            if n > 0 {
                let selected = n.min(remaining);
                sum += total * selected as f64 / n as f64;
                remaining -= selected;
                if remaining == 0 {
                    break;
                }
            }
        }
        Some(sum / take as f64)
    }
}

fn next_source_packet(
    format: &mut dyn FormatReader,
    track_id: u32,
    job: &AudioSourceAnalysisJob,
) -> Result<Option<Packet>, AudioSourceAnalysisStatus> {
    loop {
        if job.is_cancelled() {
            return Err(AudioSourceAnalysisStatus::Cancelled);
        }
        match format.next_packet() {
            Ok(Some(packet)) if packet.track_id == track_id => return Ok(Some(packet)),
            Ok(Some(_)) => {}
            Ok(None) => return Ok(None),
            Err(_) => return Err(AudioSourceAnalysisStatus::Unreadable),
        }
    }
}

fn analyze_source_audio_file_inner(
    path: &str,
    job: &AudioSourceAnalysisJob,
) -> AudioSourceAnalysis {
    if job.is_cancelled() {
        return empty_source_analysis(AudioSourceAnalysisStatus::Cancelled, 0);
    }
    let path_obj = Path::new(path);

    if let Some(ext) = path_obj.extension().and_then(|e| e.to_str()) {
        match ext.to_lowercase().as_str() {
            "dsf" | "dff" | "wv" => {
                return empty_source_analysis(AudioSourceAnalysisStatus::UnsupportedFormat, 0);
            }
            _ => {}
        }
    }

    let file = match File::open(path_obj) {
        Ok(file) => file,
        Err(_) => return empty_source_analysis(AudioSourceAnalysisStatus::Unreadable, 0),
    };
    let file_size = match file.metadata() {
        Ok(metadata) if metadata.is_file() => metadata.len(),
        _ => return empty_source_analysis(AudioSourceAnalysisStatus::Unreadable, 0),
    };

    let mss = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(ext) = path_obj.extension().and_then(|e| e.to_str()) {
        hint.with_extension(ext);
    }

    let mut format_ctx = match symphonia::default::get_probe().probe(
        &hint,
        mss,
        FormatOptions::default(),
        MetadataOptions::default(),
    ) {
        Ok(probed) => probed,
        Err(_) => {
            return empty_source_analysis(AudioSourceAnalysisStatus::UnsupportedFormat, file_size)
        }
    };

    let (codec_params, track_id, num_frames) = {
        let track = match format_ctx.default_track(TrackType::Audio) {
            Some(track) => track,
            None => {
                return empty_source_analysis(AudioSourceAnalysisStatus::NoAudioStream, file_size)
            }
        };
        let params = match &track.codec_params {
            Some(CodecParameters::Audio(p)) if p.codec != CODEC_ID_NULL_AUDIO => p.clone(),
            _ => return empty_source_analysis(AudioSourceAnalysisStatus::NoAudioStream, file_size),
        };
        (params, track.id, track.num_frames)
    };

    if codec_params
        .channels
        .as_ref()
        .is_some_and(|c| c.count() > 2)
    {
        return empty_source_analysis(
            AudioSourceAnalysisStatus::UnsupportedMultichannel,
            file_size,
        );
    }
    let bit_depth = codec_params.bits_per_sample;

    let mut decoder = match symphonia::default::get_codecs()
        .make_audio_decoder(&codec_params, &AudioDecoderOptions::default())
    {
        Ok(decoder) => decoder,
        Err(_) => {
            return empty_source_analysis(AudioSourceAnalysisStatus::UnsupportedFormat, file_size)
        }
    };

    // Use the actual decoder output (e.g. the container may not specify a
    // rate/layout, or may report a coded rather than decoded frame rate).
    let mut interleaved: Vec<f64> = Vec::new();
    let (sample_rate, channels, integer_samples) = loop {
        let packet = match next_source_packet(format_ctx.as_mut(), track_id, job) {
            Ok(Some(packet)) => packet,
            Ok(None) => {
                return empty_source_analysis(AudioSourceAnalysisStatus::NoSamples, file_size)
            }
            Err(status) => return empty_source_analysis(status, file_size),
        };
        let Ok(decoded) = decoder.decode(&packet) else {
            return empty_source_analysis(AudioSourceAnalysisStatus::Unreadable, file_size);
        };
        if decoded.frames() > 0 {
            let spec = decoded.spec();
            let actual_channels = spec.channels().count();
            if actual_channels > 2 {
                return empty_source_analysis(
                    AudioSourceAnalysisStatus::UnsupportedMultichannel,
                    file_size,
                );
            }
            if actual_channels == 0 || !(4_000..=1_536_000).contains(&spec.rate()) {
                return empty_source_analysis(
                    AudioSourceAnalysisStatus::UnsupportedFormat,
                    file_size,
                );
            }
            decoded.copy_to_vec_interleaved(&mut interleaved);
            let integer_samples = !matches!(
                decoded,
                symphonia::core::audio::GenericAudioBufferRef::F32(_)
                    | symphonia::core::audio::GenericAudioBufferRef::F64(_)
            );
            break (spec.rate(), actual_channels, integer_samples);
        }
    };

    let sample_rate_f = sample_rate as f64;
    let (k1b, k1a, k2b, k2a) = k_filter_coefficients(sample_rate_f);
    let mut k_filters: Vec<[Biquad; 2]> = (0..channels)
        .map(|_| [Biquad::new(k1b, k1a), Biquad::new(k2b, k2a)])
        .collect();
    let tp_coeffs = true_peak_coefficients();
    let tp_step = if sample_rate < 96_000 {
        1
    } else if sample_rate < 192_000 {
        2
    } else {
        TP_PHASES
    };
    let mut tp_history = vec![[0.0f64; TP_TAPS]; channels];

    let chunk_frames = ((sample_rate + 5) / 10) as usize;
    let mut chunk_energy = 0.0;
    let mut energy_history = VecDeque::<f64>::with_capacity(30);
    let mut lufs_blocks = MeasurementHistogram::new();
    let mut short_term_blocks = MeasurementHistogram::new();

    let dr_block = (3.0 * sample_rate_f) as usize;
    let mut dr_peak = 0.0f64;
    let mut dr_sq = 0.0f64;
    let mut dr_frames = 0usize;
    let mut dr_vals = MeasurementHistogram::new();

    let mut channel_peak = vec![0.0f64; channels];
    let mut channel_sq = vec![0.0f64; channels];
    let mut mid_sq = 0.0f64;
    let mut side_sq = 0.0f64;

    let mut true_peak = 0.0f64;
    let mut clipped_samples = 0u64;

    let mut first_loud: Option<u64> = None;
    let mut last_loud: Option<u64> = None;
    let mut frames_seen = 0u64;

    let window = hann_window(SPECTROGRAM_FFT_SIZE);
    let bin_positions =
        spectrogram_bin_positions(sample_rate_f, SPECTROGRAM_FFT_SIZE, SPECTROGRAM_BINS);
    let mut planner = RealFftPlanner::<f64>::new();
    let fft = planner.plan_fft_forward(SPECTROGRAM_FFT_SIZE);
    let mut fft_input = fft.make_input_vec();
    let mut fft_output = fft.make_output_vec();
    let mut fft_scratch = fft.make_scratch_vec();
    let mut spectrograms: Vec<_> = (0..channels).map(|_| SpectrumColumns::new()).collect();
    let mut rings: Vec<VecDeque<f64>> = (0..channels)
        .map(|_| {
            let mut ring = VecDeque::with_capacity(SPECTROGRAM_FFT_SIZE);
            ring.resize(SPECTROGRAM_HOP, 0.0);
            ring
        })
        .collect();
    let mut window_index = 0;
    let mut render_window = |rings: &mut [VecDeque<f64>], window_index| {
        for (ring, spectrum) in rings.iter_mut().zip(&mut spectrograms) {
            spectrogram_column(
                ring,
                fft.as_ref(),
                &mut fft_input,
                &mut fft_output,
                &mut fft_scratch,
                &window,
                &bin_positions,
                spectrum.column(window_index),
            );
            ring.drain(..SPECTROGRAM_HOP);
        }
    };

    // Integer PCM has an asymmetric range: +full scale is one step below +1.
    let positive_full_scale = bit_depth
        .filter(|bits| integer_samples && (1..=32).contains(bits))
        .map_or(1.0, |bits| 1.0 - 2.0_f64.powi(1 - bits as i32));
    loop {
        for frame in interleaved.chunks_exact(channels) {
            if frames_seen % 2048 == 0 && job.is_cancelled() {
                return empty_source_analysis(AudioSourceAnalysisStatus::Cancelled, file_size);
            }
            let mut samples = [0.0; 2];
            let mut frame_peak = 0.0f64;
            let mut wss = 0.0f64;

            for (c, &sample) in frame.iter().enumerate() {
                if !sample.is_finite() {
                    return empty_source_analysis(AudioSourceAnalysisStatus::Unreadable, file_size);
                }
                samples[c] = sample;
                let abs = sample.abs();
                if abs > frame_peak {
                    frame_peak = abs;
                }
                if abs > channel_peak[c] {
                    channel_peak[c] = abs;
                }
                channel_sq[c] += sample * sample;

                let [ref mut stage1, ref mut stage2] = k_filters[c];
                let filtered = stage2.process(stage1.process(sample));
                wss += filtered * filtered;

                true_peak = true_peak.max(interpolated_peak(
                    &mut tp_history[c],
                    sample,
                    &tp_coeffs,
                    tp_step,
                ));
                rings[c].push_back(sample);

                if sample <= -1.0 || sample >= positive_full_scale {
                    clipped_samples += 1;
                }
            }

            let [left, right] = samples;
            if channels > 1 {
                let mid = (left + right) * 0.5;
                let side = (left - right) * 0.5;
                mid_sq += mid * mid;
                side_sq += side * side;
            }

            if frame_peak >= SILENCE_THRESHOLD {
                if first_loud.is_none() {
                    first_loud = Some(frames_seen);
                }
                last_loud = Some(frames_seen);
            }

            frames_seen += 1;
            chunk_energy += wss;
            if frames_seen % chunk_frames as u64 == 0 {
                if energy_history.len() == 30 {
                    energy_history.pop_front();
                }
                energy_history.push_back(chunk_energy / chunk_frames as f64);
                chunk_energy = 0.0;
                if energy_history.len() >= 4 {
                    lufs_blocks
                        .record_energy(energy_history.iter().rev().take(4).sum::<f64>() / 4.0);
                }
                if energy_history.len() == 30 && frames_seen % (10 * chunk_frames) as u64 == 0 {
                    short_term_blocks.record_energy(energy_history.iter().sum::<f64>() / 30.0);
                }
            }

            if frame_peak > dr_peak {
                dr_peak = frame_peak;
            }
            dr_sq += left * left + right * right;
            dr_frames += 1;
            if dr_frames >= dr_block {
                let rms = (dr_sq / (dr_frames as f64 * channels as f64)).sqrt();
                if rms > 0.001 && dr_peak > 0.0 {
                    let crest = 20.0 * (dr_peak / rms).log10();
                    dr_vals.record(crest, crest);
                }
                dr_peak = 0.0;
                dr_sq = 0.0;
                dr_frames = 0;
            }

            if rings[0].len() == SPECTROGRAM_FFT_SIZE {
                render_window(&mut rings, window_index);
                window_index += 1;
            }
        }

        if let Some(total) = num_frames.filter(|&t| t > 0) {
            let progress = ((frames_seen as u128 * ANALYSIS_PROGRESS_MAX as u128) / total as u128)
                .min((ANALYSIS_PROGRESS_MAX - 1) as u128) as u32;
            job.progress.store(progress, Ordering::Relaxed);
        }

        let packet = match next_source_packet(format_ctx.as_mut(), track_id, job) {
            Ok(Some(packet)) => packet,
            Ok(None) => break,
            Err(status) => return empty_source_analysis(status, file_size),
        };
        let Ok(decoded) = decoder.decode(&packet) else {
            return empty_source_analysis(AudioSourceAnalysisStatus::Unreadable, file_size);
        };
        if decoded.frames() == 0 {
            interleaved.clear();
            continue;
        }
        if decoded.spec().channels().count() > 2 {
            return empty_source_analysis(
                AudioSourceAnalysisStatus::UnsupportedMultichannel,
                file_size,
            );
        }
        if decoded.spec().channels().count() != channels || decoded.spec().rate() != sample_rate {
            return empty_source_analysis(AudioSourceAnalysisStatus::UnsupportedFormat, file_size);
        }
        decoded.copy_to_vec_interleaved(&mut interleaved);
    }

    for ring in &mut rings {
        ring.resize(SPECTROGRAM_FFT_SIZE, 0.0);
    }
    render_window(&mut rings, window_index);
    if frames_seen % SPECTROGRAM_HOP as u64 != 0 {
        // Include one padded window beyond the last full hop so short tail
        // events aren't lost at the edge of the Hann window.
        for ring in &mut rings {
            ring.resize(SPECTROGRAM_FFT_SIZE, 0.0);
        }
        render_window(&mut rings, window_index + 1);
    }
    for history in &mut tp_history {
        for _ in 0..TP_DELAY {
            true_peak = true_peak.max(interpolated_peak(history, 0.0, &tp_coeffs, tp_step));
        }
    }

    // Flush partial blocks so short tracks still get useful values.
    if dr_frames > 0 {
        let rms = (dr_sq / (dr_frames as f64 * channels as f64)).sqrt();
        if rms > 0.001 && dr_peak > 0.0 {
            let crest = 20.0 * (dr_peak / rms).log10();
            dr_vals.record(crest, crest);
        }
    }

    let dr = dr_vals.mean_top_fifth();

    let duration_seconds = frames_seen as f64 / sample_rate_f;
    let channel_peak_db: Vec<f64> = channel_peak
        .iter()
        .map(|&peak| amplitude_to_db(peak))
        .collect();
    let channel_rms_db: Vec<f64> = channel_sq
        .iter()
        .map(|&sum| amplitude_to_db((sum / frames_seen as f64).sqrt()))
        .collect();

    let balance_db = if channels > 1 && channel_sq[0] > 0.0 && channel_sq[1] > 0.0 {
        Some(10.0 * (channel_sq[0] / channel_sq[1]).log10())
    } else {
        None
    };
    let side_mid_db = if channels > 1 && side_sq > 1e-12 && mid_sq > 1e-12 {
        Some(10.0 * (side_sq / mid_sq).log10())
    } else {
        None
    };

    let leading_silence_seconds = if first_loud.is_none() {
        Some(duration_seconds)
    } else {
        Some(first_loud.unwrap() as f64 / sample_rate_f)
    };
    let trailing_silence_seconds = if let Some(last) = last_loud {
        Some((frames_seen.saturating_sub(last + 1)) as f64 / sample_rate_f)
    } else {
        Some(0.0)
    };

    let lufs = lufs_blocks
        .relative_gate(-10.0)
        .and_then(|gate| lufs_blocks.mean_above(gate))
        .map(|mean| -0.691 + 10.0 * mean.log10());
    let lra = short_term_blocks.loudness_range();
    let true_peak_db = (true_peak > 0.0).then(|| amplitude_to_db(true_peak));

    let mut data = spectrograms.into_iter().map(|spectrum| {
        let mut db = spectrum.data;
        db.iter_mut().for_each(|power| *power = power_to_db(*power));
        db
    });
    let left_db = data.next().unwrap();
    let spectrogram = AudioSourceSpectrogram {
        columns: (left_db.len() / SPECTROGRAM_BINS) as u32,
        bins: SPECTROGRAM_BINS as u32,
        min_frequency_hz: SPECTROGRAM_MIN_HZ,
        max_frequency_hz: sample_rate_f / 2.0,
        left_db,
        right_db: data.next().unwrap_or_default(),
    };
    if job.is_cancelled() {
        return empty_source_analysis(AudioSourceAnalysisStatus::Cancelled, file_size);
    }

    AudioSourceAnalysis {
        status: AudioSourceAnalysisStatus::Ok,
        file_size_bytes: file_size,
        duration_seconds: Some(duration_seconds),
        sample_rate: Some(sample_rate),
        channels: Some(channels as u32),
        bit_depth,
        channel_peak_db,
        channel_rms_db,
        balance_db,
        side_mid_db,
        leading_silence_seconds,
        trailing_silence_seconds,
        silent: first_loud.is_none(),
        lufs,
        lra,
        true_peak_db,
        dr,
        clipping: clipped_samples > 0,
        clipped_samples,
        spectrogram: Some(spectrogram),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::f64::consts::PI;

    /// Generate a 48 kHz stereo WAV with a sine at known amplitude.
    fn write_sine_wav(dir: &std::path::Path, name: &str, freq: f64, amp: f64, secs: f64) -> String {
        let sr: u32 = 48000;
        let n = (secs * sr as f64) as usize;
        let path = dir.join(name);

        let mut wtr = hound::WavWriter::create(
            &path,
            hound::WavSpec {
                channels: 2,
                sample_rate: sr,
                bits_per_sample: 16,
                sample_format: hound::SampleFormat::Int,
            },
        )
        .unwrap();

        for i in 0..n {
            let t = i as f64 / sr as f64;
            let s = (t * freq * 2.0 * PI).sin() * amp;
            let s16 = (s * 32767.0) as i16;
            wtr.write_sample(s16).unwrap();
            wtr.write_sample(s16).unwrap();
        }
        wtr.finalize().unwrap();

        path.to_string_lossy().into_owned()
    }

    fn write_square_wav(dir: &std::path::Path, name: &str, amp: f64, secs: f64) -> String {
        let sr: u32 = 48000;
        let n = (secs * sr as f64) as usize;
        let path = dir.join(name);

        let mut wtr = hound::WavWriter::create(
            &path,
            hound::WavSpec {
                channels: 2,
                sample_rate: sr,
                bits_per_sample: 16,
                sample_format: hound::SampleFormat::Int,
            },
        )
        .unwrap();

        let period = sr as usize / 1000; // 1 kHz square
        for i in 0..n {
            let s = if (i / period) % 2 == 0 { amp } else { -amp };
            let s16 = (s * 32767.0) as i16;
            wtr.write_sample(s16).unwrap();
            wtr.write_sample(s16).unwrap();
        }
        wtr.finalize().unwrap();

        path.to_string_lossy().into_owned()
    }

    #[test]
    fn sine_peaks_and_lufs() {
        let dir = std::env::temp_dir().join("flick_test_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        let path = write_sine_wav(&dir, "sine.wav", 1000.0, 0.5, 3.0);

        let result = analyze_audio_file(path, 240).expect("analysis should succeed");

        // Peaks: 240 buckets, all normalised 0..1, at least one non-zero.
        assert_eq!(result.peaks.len(), 240);
        assert!(result.peaks.iter().any(|&p| p > 0.5));
        assert!(result.peaks.iter().all(|&p| p >= 0.0 && p <= 1.0));

        // LUFS: a 1 kHz sine at -6.02 dBFS RMS ≈ -6.71 LUFS (mono weighting
        // on stereo with identical channels ≈ -6.71 LUFS). Allow ±2 LU.
        let lufs = result.lufs.expect("lufs should be present");
        assert!((lufs - (-6.7)).abs() < 2.0, "lufs={lufs}, expected ≈ -6.7");

        // True peak should be near -6.02 dB (sine at 0.5 amplitude).
        let tp = result.true_peak_db.expect("true peak should be present");
        assert!(
            (tp - (-6.02)).abs() < 1.0,
            "true_peak_db={tp}, expected ≈ -6.02"
        );

        // Not clipping.
        assert!(!result.clipping);
    }

    #[test]
    fn square_clipping() {
        let dir = std::env::temp_dir().join("flick_test_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        let path = write_square_wav(&dir, "square.wav", 1.0, 2.0);

        let result = analyze_audio_file(path, 240).expect("analysis should succeed");

        // Full-scale square: clipping detected.
        assert!(result.clipping);

        // True peak ≈ 0 dB.
        let tp = result.true_peak_db.expect("true peak should be present");
        assert!(tp.abs() < 0.5, "true_peak_db={tp}, expected ≈ 0.0");
    }

    #[test]
    fn unsupported_format_returns_none() {
        let result = analyze_audio_file("/tmp/nonexistent.dsf".into(), 240);
        assert!(result.is_none());
    }

    fn write_wav_frames<F>(
        dir: &std::path::Path,
        name: &str,
        sample_rate: u32,
        channels: u16,
        frames: usize,
        mut sample_at: F,
    ) -> String
    where
        F: FnMut(usize, usize) -> f64,
    {
        let path = dir.join(name);
        let mut writer = hound::WavWriter::create(
            &path,
            hound::WavSpec {
                channels,
                sample_rate,
                bits_per_sample: 16,
                sample_format: hound::SampleFormat::Int,
            },
        )
        .unwrap();

        for frame in 0..frames {
            for channel in 0..channels as usize {
                let value = (sample_at(channel, frame).clamp(-1.0, 1.0) * 32767.0).round() as i16;
                writer.write_sample(value).unwrap();
            }
        }
        writer.finalize().unwrap();

        path.to_string_lossy().into_owned()
    }

    fn analyze_source(path: String) -> AudioSourceAnalysis {
        // Measurement tests need not contend for the production job slot.
        analyze_source_audio_file_inner(&path, &create_source_audio_analysis_job())
    }

    #[test]
    fn k_filter_design_matches_48k_constants() {
        let (b1, a1, b2, a2) = k_filter_coefficients(48_000.0);

        for i in 0..3 {
            assert!(
                (b1[i] - K_S1_B[i]).abs() < 1e-6,
                "stage 1 b[{i}] = {}, expected {}",
                b1[i],
                K_S1_B[i]
            );
            assert!(
                (b2[i] - K_S2_B[i]).abs() < 1e-6,
                "stage 2 b[{i}] = {}, expected {}",
                b2[i],
                K_S2_B[i]
            );
        }
        for i in 0..2 {
            assert!(
                (a1[i] - K_S1_A[i]).abs() < 1e-6,
                "stage 1 a[{i}] = {}, expected {}",
                a1[i],
                K_S1_A[i]
            );
            assert!(
                (a2[i] - K_S2_A[i]).abs() < 1e-6,
                "stage 2 a[{i}] = {}, expected {}",
                a2[i],
                K_S2_A[i]
            );
        }
    }

    #[test]
    fn source_analysis_sine_metrics() {
        let dir = std::env::temp_dir().join("flick_test_source_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        let path = write_wav_frames(&dir, "source_sine.wav", 48_000, 2, 144_000, |_, frame| {
            (2.0 * PI * 1000.0 * frame as f64 / 48_000.0).sin() * 0.5
        });

        let result = analyze_source(path);

        assert_eq!(result.status, AudioSourceAnalysisStatus::Ok);
        assert!(result.file_size_bytes > 0);
        assert!((result.duration_seconds.unwrap() - 3.0).abs() < 0.01);
        assert_eq!(result.sample_rate, Some(48_000));
        assert_eq!(result.channels, Some(2));
        assert_eq!(result.bit_depth, Some(16));

        assert!((result.channel_peak_db[0] - (-6.02)).abs() < 0.2);
        assert!((result.channel_rms_db[0] - (-9.03)).abs() < 0.2);
        assert!(result.balance_db.unwrap().abs() < 0.01);
        assert!(result.side_mid_db.is_none());

        let lufs = result.lufs.expect("lufs should be present");
        assert!((lufs - (-6.0)).abs() < 0.2, "lufs={lufs}");

        let true_peak = result.true_peak_db.expect("true peak should be present");
        assert!(
            (true_peak - (-6.02)).abs() < 0.6,
            "true_peak_db={true_peak}"
        );

        let dr = result.dr.expect("dynamic range should be present");
        assert!((dr - 3.01).abs() < 0.5, "dr={dr}");

        let spectrogram = result.spectrogram.expect("spectrogram should be present");
        assert_eq!(spectrogram.bins, 192);
        assert_eq!(spectrogram.min_frequency_hz, 20.0);
        assert_eq!(spectrogram.max_frequency_hz, 24_000.0);
        assert!(spectrogram.columns > 100);
        assert_eq!(
            spectrogram.left_db.len(),
            spectrogram.columns as usize * spectrogram.bins as usize
        );
        assert_eq!(spectrogram.right_db.len(), spectrogram.left_db.len());
        assert!(spectrogram.left_db.iter().any(|&value| value > -20.0));
    }

    #[test]
    fn source_analysis_silence_bounds() {
        let dir = std::env::temp_dir().join("flick_test_source_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        let path = write_wav_frames(&dir, "source_silence.wav", 48_000, 2, 96_000, |_, frame| {
            if (24_000..72_000).contains(&frame) {
                (2.0 * PI * 1000.0 * (frame - 24_000) as f64 / 48_000.0).sin() * 0.25
            } else {
                0.0
            }
        });

        let result = analyze_source(path);

        assert_eq!(result.status, AudioSourceAnalysisStatus::Ok);
        assert!(!result.silent);
        assert!((result.leading_silence_seconds.unwrap() - 0.5).abs() < 0.01);
        assert!((result.trailing_silence_seconds.unwrap() - 0.5).abs() < 0.01);
    }

    #[test]
    fn source_analysis_stereo_balance_and_side_mid() {
        let dir = std::env::temp_dir().join("flick_test_source_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        let path = write_wav_frames(
            &dir,
            "source_stereo.wav",
            48_000,
            2,
            48_000,
            |channel, frame| {
                let amplitude = if channel == 0 { 0.5 } else { 0.25 };
                (2.0 * PI * 1000.0 * frame as f64 / 48_000.0).sin() * amplitude
            },
        );

        let result = analyze_source(path);

        assert_eq!(result.status, AudioSourceAnalysisStatus::Ok);
        assert!(
            (result.balance_db.unwrap() - 6.02).abs() < 0.1,
            "balance={:?}",
            result.balance_db
        );
        assert!(
            (result.side_mid_db.unwrap() - (-9.54)).abs() < 0.1,
            "side/mid={:?}",
            result.side_mid_db
        );
    }

    #[test]
    fn source_analysis_true_peak_inter_sample() {
        let dir = std::env::temp_dir().join("flick_test_source_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        // 12 kHz at 48 kHz with a 45° phase: even at 1.25× amplitude the
        // samples stay below full scale, while the true peak exceeds it.
        let path = write_wav_frames(
            &dir,
            "source_true_peak.wav",
            48_000,
            2,
            24_000,
            |_, frame| (2.0 * PI * 12_000.0 * frame as f64 / 48_000.0 + PI / 4.0).sin() * 1.25,
        );

        let result = analyze_source(path);

        assert_eq!(result.status, AudioSourceAnalysisStatus::Ok);
        assert!(
            (result.channel_peak_db[0] - (-1.07)).abs() < 0.1,
            "sample peak={}",
            result.channel_peak_db[0]
        );
        let true_peak = result.true_peak_db.unwrap();
        assert!(
            (true_peak - 2.5).abs() < 0.6,
            "true_peak_db={true_peak}, FFmpeg reference +2.5"
        );
        assert_eq!(result.clipped_samples, 0);
    }

    #[test]
    fn source_analysis_rejects_multichannel() {
        let dir = std::env::temp_dir().join("flick_test_source_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        let path = write_wav_frames(
            &dir,
            "source_multichannel.wav",
            48_000,
            3,
            4_800,
            |_, frame| (2.0 * PI * 1000.0 * frame as f64 / 48_000.0).sin() * 0.25,
        );

        let result = analyze_source(path);

        assert_eq!(
            result.status,
            AudioSourceAnalysisStatus::UnsupportedMultichannel
        );
    }

    #[test]
    fn source_analysis_rejects_dsd() {
        let result = analyze_source("/tmp/flick_nonexistent.dsf".to_string());
        assert_eq!(result.status, AudioSourceAnalysisStatus::UnsupportedFormat);
    }

    #[test]
    fn source_analysis_matches_reference_loudness_at_multiple_rates() {
        let dir = std::env::temp_dir().join("flick_test_source_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        // Reference: a 1 kHz sine at 0.05, 0.25 and 0.5 amplitude, seven
        // seconds each, measured with FFmpeg ebur128=peak=true.
        for (rate, reference_lufs) in [(44_100, -11.1), (48_000, -11.1), (96_000, -11.2)] {
            let path = write_wav_frames(
                &dir,
                &format!("loudness_{rate}.wav"),
                rate,
                1,
                (21 * rate) as usize,
                |_, frame| {
                    let amplitude = [0.05, 0.25, 0.5][frame / (7 * rate as usize)];
                    (2.0 * PI * 1000.0 * frame as f64 / rate as f64).sin() * amplitude
                },
            );
            let result = analyze_source(path);
            assert_eq!(result.status, AudioSourceAnalysisStatus::Ok);
            let (lufs, lra, peak) = (
                result.lufs.unwrap(),
                result.lra.unwrap(),
                result.true_peak_db.unwrap(),
            );
            assert!(
                (lufs - reference_lufs).abs() <= 0.15,
                "{rate} Hz: {lufs} LUFS"
            );
            assert!((lra - 20.0).abs() <= 0.15, "{rate} Hz: {lra} LU");
            assert!((peak + 6.0).abs() <= 0.15, "{rate} Hz: {peak} dBTP");
        }
    }

    #[test]
    fn source_analysis_tracks_exact_pcm_rails() {
        let dir = std::env::temp_dir().join("flick_test_source_analysis");
        std::fs::create_dir_all(&dir).unwrap();
        let path = write_wav_frames(&dir, "source_clip.wav", 48_000, 1, 32, |_, i| match i {
            0 => 1.0,
            1 => 32766.0 / 32767.0,
            _ => 0.0,
        });
        let result = analyze_source(path);
        assert_eq!(result.status, AudioSourceAnalysisStatus::Ok);
        assert_eq!(result.clipped_samples, 1);
        assert!(result.clipping);
    }

    #[test]
    fn source_analysis_job_cancellation_is_sticky_and_isolated() {
        let a = create_source_audio_analysis_job();
        let b = create_source_audio_analysis_job();
        a.cancel();
        let _slot = SOURCE_ANALYZER.lock().unwrap();
        let path = "/tmp/flick_nonexistent.dsf";
        assert_eq!(
            a.analyze(path.into()).status,
            AudioSourceAnalysisStatus::Cancelled
        );
        assert_eq!(
            b.analyze(path.into()).status,
            AudioSourceAnalysisStatus::Busy
        );
        assert!(!b.is_cancelled());
        assert_eq!(b.progress(), 0.0);
    }

    #[test]
    fn spectrum_buckets_retain_late_windows_after_multiple_merges() {
        let mut spectrum = SpectrumColumns::new();
        let events = [101, 1027, 2047, 2050, 4098];
        for index in 0..=4100 {
            let column = spectrum.column(index);
            if let Some(bin) = events.iter().position(|&event| event == index) {
                column[bin] = index as f32;
            }
        }
        assert_eq!(spectrum.windows_per_column, 8);
        assert_eq!(spectrum.data.len() / SPECTROGRAM_BINS, 513);
        for (bin, event) in events.into_iter().enumerate() {
            assert_eq!(
                spectrum.data[(event / 8) * SPECTROGRAM_BINS + bin],
                event as f32
            );
        }
    }
}
