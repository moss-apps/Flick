//! Pitch shifter: shifts pitch in semitones independent of tempo.
//! Wraps the bundled SoundTouch library (C++ via its SoundTouchDLL C API).
//! Single responsibility: pitch-shift interleaved f32 samples in place.

use soundtouch_sys as st;
use std::collections::VecDeque;
use std::sync::atomic::{AtomicU32, Ordering};

/// Clamp for the semitone offset accepted from Dart.
pub const MAX_SEMITONES: f32 = 12.0;

static PROCESS_LOG_COUNTER: AtomicU32 = AtomicU32::new(0);
static BYPASS_LOG_COUNTER: AtomicU32 = AtomicU32::new(0);

/// RAII wrapper around a SoundTouch instance.
///
/// SoundTouch is a pull-style processor with bursty delivery (±20% per call,
/// per probing): output only roughly matches input per callback. `pending`
/// absorbs the jitter so `process` always emits exactly the requested frames;
/// the startup latency (~130 ms) is zero-filled once.
pub struct PitchShifter {
    handle: st::SoundTouchHandle,
    channels: usize,
    semitones: f32,
    /// Decoded-output backlog: everything SoundTouch has produced but the
    /// callback hasn't consumed yet.
    pending: VecDeque<f32>,
    /// Scratch for receiving SoundTouch output before pushing to `pending`.
    scratch: Vec<f32>,
}

// The handle is only touched behind the engine's Mutex<PitchShifter>.
unsafe impl Send for PitchShifter {}

impl PitchShifter {
    pub fn new(sample_rate: u32, channels: usize) -> Self {
        let handle = unsafe { st::soundtouch_createInstance() };
        assert!(!handle.is_null(), "soundtouch_createInstance failed");
        unsafe {
            st::soundtouch_setSampleRate(handle, sample_rate);
            st::soundtouch_setChannels(handle, channels as u32);
        }
        let channels = channels.max(1);
        Self {
            handle,
            channels,
            semitones: 0.0,
            // Backlog peaks around (latency + one callback) ≈ 12k frames.
            // Growing past this allocates on the RT thread — rare and bounded.
            pending: VecDeque::with_capacity(1 << 16),
            scratch: vec![0.0; 16384 * channels],
        }
    }

    /// Current semitone offset (0 = bypass).
    pub fn semitones(&self) -> f32 {
        self.semitones
    }

    /// Set pitch offset in semitones (clamped to ±MAX_SEMITONES). SoundTouch
    /// applies the new ratio to subsequent input; buffered output retains the
    /// old pitch for a brief transition — no dropout.
    pub fn set_semitones(&mut self, semitones: f32) {
        let semitones = semitones.clamp(-MAX_SEMITONES, MAX_SEMITONES);
        if semitones == self.semitones {
            return;
        }
        log::info!("[PITCH] set_semitones: {self_semitones} -> {semitones}", self_semitones = self.semitones);
        unsafe {
            st::soundtouch_setPitchSemiTones(self.handle, semitones);
        }
        self.semitones = semitones;
    }

    /// Flush buffered samples (seek / track boundary).
    pub fn reset(&mut self) {
        unsafe { st::soundtouch_clear(self.handle) };
        self.pending.clear();
    }

    /// Process interleaved buffer in place. Bypasses when semitones == 0.
    pub fn process(&mut self, buf: &mut [f32], channels: usize) {
        if self.semitones == 0.0 || channels == 0 || channels != self.channels {
            let n = BYPASS_LOG_COUNTER.fetch_add(1, Ordering::Relaxed);
            if n % 500 == 0 {
                log::info!(
                    "[PITCH] bypass(semitones={}, channels={}, self.channels={}) [count={}]",
                    self.semitones, channels, self.channels, n
                );
            }
            return;
        }
        let frames = buf.len() / channels;
        if frames == 0 {
            return;
        }
        let pending_before = self.pending.len();
        unsafe {
            st::soundtouch_putSamples(self.handle, buf.as_ptr(), frames as u32);
            let avail = st::soundtouch_numSamples(self.handle) as usize;
            if avail > 0 {
                let avail_samples = avail * channels;
                if self.scratch.len() < avail_samples {
                    self.scratch.resize(avail_samples, 0.0);
                }
                let got = st::soundtouch_receiveSamples(
                    self.handle,
                    self.scratch.as_mut_ptr(),
                    avail as u32,
                ) as usize;
                self.pending
                    .extend(&self.scratch[..got.min(avail) * channels]);
            }
            let n = PROCESS_LOG_COUNTER.fetch_add(1, Ordering::Relaxed);
            if n % 500 == 0 {
                log::info!(
                    "[PITCH] process(frames={}, avail={}, pending_before={}, pending_after={}) [count={}]",
                    frames, avail, pending_before, self.pending.len(), n
                );
            }
        }
        let take = buf.len().min(self.pending.len());
        for (dst, src) in buf.iter_mut().zip(self.pending.drain(..take)) {
            *dst = src;
        }
        buf[take..].fill(0.0);
    }
}

impl Drop for PitchShifter {
    fn drop(&mut self) {
        unsafe { st::soundtouch_destroyInstance(self.handle) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::f32::consts::PI;

    fn sine(freq: f32, sample_rate: u32, frames: usize, channels: usize) -> Vec<f32> {
        (0..frames)
            .flat_map(|i| {
                let s = (2.0 * PI * freq * i as f32 / sample_rate as f32).sin();
                vec![s; channels]
            })
            .collect()
    }

    /// Peak-bin frequency of the left channel. Robust to the low-level
    /// wideband artifacts SoundTouch adds (a centroid gets pulled up by them).
    fn peak_hz(buf: &[f32], channels: usize, sample_rate: u32) -> f32 {
        let n = buf.len() / channels;
        // Naive DFT magnitude on a power-of-two window; tiny and sufficient.
        let n = (n.next_power_of_two() / 2).min(4096);
        let start = (buf.len() / channels).saturating_sub(n);
        let (mut best_k, mut best_mag) = (0, 0.0f32);
        for k in 1..n / 2 {
            let (mut re, mut im) = (0.0f32, 0.0f32);
            for (i, &s) in buf[start * channels..]
                .iter()
                .step_by(channels)
                .take(n)
                .enumerate()
            {
                let phase = -2.0 * PI * k as f32 * i as f32 / n as f32;
                re += s * phase.cos();
                im += s * phase.sin();
            }
            let mag = re * re + im * im;
            if mag > best_mag {
                best_mag = mag;
                best_k = k;
            }
        }
        best_k as f32 * sample_rate as f32 / n as f32
    }

    #[test]
    fn shifts_sine_up_seven_semitones() {
        let rate = 48000;
        let channels = 2;
        let mut shifter = PitchShifter::new(rate, channels);
        shifter.set_semitones(7.0);

        // Feed in callback-sized chunks, like the engine does.
        let mut output = Vec::new();
        for chunk in sine(440.0, rate, rate as usize, channels).chunks(4096 * channels) {
            let mut buf = chunk.to_vec();
            shifter.process(&mut buf, channels);
            output.extend_from_slice(&buf);
        }

        // Measure the second half so startup latency doesn't skew the result.
        let tail = &output[output.len() / 2..];
        let hz = peak_hz(tail, channels, rate);
        let expected = 440.0 * 2f32.powf(7.0 / 12.0); // ~659.3 Hz
        assert!(
            (hz - expected).abs() < expected * 0.05,
            "peak {hz:.1} Hz, expected ~{expected:.1} Hz"
        );
    }

    #[test]
    fn bypass_at_zero_semitones() {
        let mut shifter = PitchShifter::new(48000, 2);
        let input = sine(440.0, 48000, 2048, 2);
        let mut buf = input.clone();
        shifter.process(&mut buf, 2);
        assert_eq!(buf, input);
    }
}
