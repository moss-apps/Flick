//! Real-time spectrum analyzer fed by the PCM that the engine is already
//! rendering.
//!
//! The audio callback only copies downmixed samples into a preallocated ring
//! buffer. All FFT work happens on the caller thread (the Dart polling worker),
//! so the real-time thread never allocates, blocks, or performs I/O.

use parking_lot::Mutex;
use realfft::{num_complex::Complex, RealFftPlanner, RealToComplex};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// Number of bars the Flutter visualizer expects.
pub const VISUALIZER_BAR_COUNT: usize = 48;

const MIN_FREQ_HZ: f32 = 20.0;
const MAX_FREQ_HZ: f32 = 20_000.0;
/// Bottom of the displayed dynamic range. A full-scale sine lands at 0 dB.
const MIN_DB: f32 = -90.0;
const ATTACK: f32 = 0.55;
const RELEASE: f32 = 0.12;

/// One analyzed frame. `sequence` increments whenever the audio callback
/// accepts a new block, letting Dart avoid repainting identical frames.
#[derive(Debug, Clone)]
pub struct VisualizerFrame {
    pub bars: Vec<f32>,
    pub sample_rate: u32,
    pub sequence: u64,
}

/// Callback-side tap. `push` is safe to call from the real-time audio thread.
pub struct VisualizerTap {
    active: AtomicBool,
    /// Ring buffer plus analysis bookkeeping. The audio callback only ever
    /// holds this lock for the short append, never for an FFT.
    state: Mutex<VisualizerState>,
    /// FFT scratch space. Kept separate from `state` so the analyzer can run
    /// after the capture lock has been released.
    analyzer: Mutex<VisualizerAnalyzer>,
}

impl VisualizerTap {
    pub fn new(sample_rate: u32, _channels: usize) -> Self {
        Self {
            active: AtomicBool::new(false),
            state: Mutex::new(VisualizerState::new(sample_rate)),
            analyzer: Mutex::new(VisualizerAnalyzer::new(
                sample_rate.max(8_000),
                fft_size_for(sample_rate.max(8_000)),
            )),
        }
    }

    /// Enable or disable capture. Disabling clears the history so a later
    /// activation cannot show bars from before the visualizer was hidden.
    pub fn set_active(&self, active: bool) {
        self.active.store(active, Ordering::Relaxed);
        if !active {
            // Lock order is analyzer -> state everywhere; `push` only takes
            // `state`, so the audio callback can never deadlock with this.
            self.analyzer.lock().reset();
            self.state.lock().clear();
        }
    }

    pub fn is_active(&self) -> bool {
        self.active.load(Ordering::Relaxed)
    }

    /// Rebind the analyzer after the engine's output sample rate changes.
    pub fn reconfigure(&self, sample_rate: u32) {
        let sample_rate = sample_rate.max(8_000);
        let mut analyzer = self.analyzer.lock();
        let mut state = self.state.lock();
        *analyzer =
            VisualizerAnalyzer::new(sample_rate, fft_size_for(sample_rate));
        *state = VisualizerState::new(sample_rate);
    }

    /// Downmix an interleaved PCM block into the history ring. `try_lock`
    /// keeps the audio callback non-blocking; a busy analyzer simply drops
    /// this block, which is inaudible because the tap is read-only.
    #[inline]
    pub fn push(&self, output: &[f32], channels: usize) {
        if !self.active.load(Ordering::Relaxed) || channels == 0 || output.is_empty() {
            return;
        }
        let Some(mut state) = self.state.try_lock() else {
            return;
        };
        state.push(output, channels);
    }

    /// Compute a fresh frame from the most recent window. Called from the
    /// Dart polling worker, never from the audio callback.
    ///
    /// The capture lock is only held while the window is copied into the
    /// analyzer's preallocated input buffer. The FFT then runs without it, so
    /// `push` keeps accepting audio blocks instead of dropping them for the
    /// duration of the transform.
    pub fn frame(&self) -> Option<VisualizerFrame> {
        if !self.active.load(Ordering::Relaxed) {
            return None;
        }
        // Serializes concurrent frame() calls; the audio callback never
        // touches this lock.
        let mut analyzer = self.analyzer.lock();
        let (sample_rate, sequence) = {
            let state = self.state.lock();
            if state.history_len == 0 {
                return None;
            }
            // Paused playback stops feeding the tap. Returning the last
            // analyzed frame avoids re-running the FFT 30 times a second.
            if state.analyzed_generation == Some(state.generation) {
                return state.cached_frame.clone();
            }
            let frames = state.history_len.min(state.fft_size);
            let start =
                (state.write_pos + state.history.len() - frames) % state.history.len();
            analyzer.load_window(&state.history, start, frames);
            (state.sample_rate, state.generation)
        };

        let frame = analyzer.analyze_loaded(sample_rate, sequence);
        if let Some(frame) = &frame {
            // New audio may have arrived while the FFT ran. Record the
            // generation that was actually analyzed; the next poll will see
            // the newer generation and analyze again.
            let mut state = self.state.lock();
            state.analyzed_generation = Some(sequence);
            state.cached_frame = Some(frame.clone());
        }
        frame
    }
}

struct VisualizerState {
    sample_rate: u32,
    fft_size: usize,
    history: Vec<f32>,
    write_pos: usize,
    history_len: usize,
    generation: u64,
    analyzed_generation: Option<u64>,
    cached_frame: Option<VisualizerFrame>,
}

impl VisualizerState {
    fn new(sample_rate: u32) -> Self {
        let sample_rate = sample_rate.max(8_000);
        let fft_size = fft_size_for(sample_rate);
        let history_capacity = (fft_size * 3).max(4096);
        Self {
            sample_rate,
            fft_size,
            history: vec![0.0; history_capacity],
            write_pos: 0,
            history_len: 0,
            generation: 0,
            analyzed_generation: None,
            cached_frame: None,
        }
    }

    fn clear(&mut self) {
        self.write_pos = 0;
        self.history_len = 0;
        self.generation = 0;
        self.analyzed_generation = None;
        self.cached_frame = None;
    }

    #[inline]
    fn push(&mut self, output: &[f32], channels: usize) {
        let capacity = self.history.len();
        let mut accepted = false;
        for frame in output.chunks_exact(channels) {
            let sum: f32 = frame.iter().copied().sum();
            let mono = if sum.is_finite() {
                sum / channels as f32
            } else {
                0.0
            };
            self.history[self.write_pos] = mono;
            self.write_pos = (self.write_pos + 1) % capacity;
            self.history_len = (self.history_len + 1).min(capacity);
            accepted = true;
        }
        if accepted {
            self.generation = self.generation.wrapping_add(1);
        }
    }
}

/// ~40 ms window: enough low-frequency resolution to make bass bars move,
/// while staying responsive enough for transients.
fn fft_size_for(sample_rate: u32) -> usize {
    let target = (sample_rate as f32 / 25.0).round() as usize;
    target.next_power_of_two().clamp(512, 8192)
}

struct VisualizerAnalyzer {
    sample_rate: u32,
    fft_size: usize,
    window: Vec<f32>,
    window_sum: f32,
    input: Vec<f32>,
    spectrum: Vec<Complex<f32>>,
    scratch: Vec<Complex<f32>>,
    plan: Arc<dyn RealToComplex<f32>>,
    band_ranges: Vec<(usize, usize)>,
    bars: [f32; VISUALIZER_BAR_COUNT],
}

impl VisualizerAnalyzer {
    fn new(sample_rate: u32, fft_size: usize) -> Self {
        let mut planner = RealFftPlanner::<f32>::new();
        let plan = planner.plan_fft_forward(fft_size);
        let input = plan.make_input_vec();
        let spectrum = plan.make_output_vec();
        let scratch = plan.make_scratch_vec();
        let window = hann_window(fft_size);
        let window_sum = window.iter().sum::<f32>().max(f32::EPSILON);
        let band_ranges = band_ranges(sample_rate, fft_size, spectrum.len());
        Self {
            sample_rate,
            fft_size,
            window,
            window_sum,
            input,
            spectrum,
            scratch,
            plan,
            band_ranges,
            bars: [0.0; VISUALIZER_BAR_COUNT],
        }
    }

    fn reset(&mut self) {
        self.bars.fill(0.0);
    }

    /// Copy one window out of the history ring into the preallocated FFT
    /// input. Called while the capture lock is held, but it is only a linear
    /// copy with no FFT work.
    fn load_window(&mut self, history: &[f32], start: usize, frames: usize) {
        self.input.fill(0.0);
        let copy_len = frames.min(self.fft_size).min(history.len());
        for i in 0..copy_len {
            self.input[i] = history[(start + i) % history.len()];
        }
    }

    /// Window and transform the samples loaded by [`Self::load_window`].
    /// Runs without the capture lock, so the audio callback is never blocked
    /// by the FFT.
    fn analyze_loaded(
        &mut self,
        sample_rate: u32,
        sequence: u64,
    ) -> Option<VisualizerFrame> {
        if sample_rate != self.sample_rate {
            // Reconfigure is supposed to run before this can happen; rebuild
            // and let the next poll load a correctly sized window.
            *self = Self::new(sample_rate, fft_size_for(sample_rate));
            return None;
        }

        for (sample, window) in self.input.iter_mut().zip(self.window.iter()) {
            *sample *= *window;
        }

        if self
            .plan
            .process_with_scratch(&mut self.input, &mut self.spectrum, &mut self.scratch)
            .is_err()
        {
            return None;
        }

        let scale = 2.0 / self.window_sum;
        for (bar, &(start_bin, end_bin)) in
            self.bars.iter_mut().zip(self.band_ranges.iter())
        {
            let mut peak = 0.0f32;
            for bin in start_bin..end_bin {
                let value = self.spectrum[bin];
                let magnitude = value.re.hypot(value.im);
                if magnitude > peak {
                    peak = magnitude;
                }
            }
            let db = 20.0 * (peak * scale).max(1.0e-9).log10();
            let target = ((db - MIN_DB) / -MIN_DB).clamp(0.0, 1.0);
            let coefficient = if target > *bar { ATTACK } else { RELEASE };
            *bar += (target - *bar) * coefficient;
        }

        Some(VisualizerFrame {
            bars: self.bars.to_vec(),
            sample_rate,
            sequence,
        })
    }
}

fn hann_window(size: usize) -> Vec<f32> {
    if size <= 1 {
        return vec![1.0; size];
    }
    (0..size)
        .map(|i| {
            let phase = 2.0 * std::f32::consts::PI * i as f32 / (size - 1) as f32;
            0.5 - 0.5 * phase.cos()
        })
        .collect()
}

fn band_ranges(
    sample_rate: u32,
    fft_size: usize,
    complex_len: usize,
) -> Vec<(usize, usize)> {
    let nyquist = sample_rate as f32 / 2.0;
    let max_freq = MAX_FREQ_HZ.min(nyquist).max(MIN_FREQ_HZ * 1.1);
    let log_span = (max_freq / MIN_FREQ_HZ).ln();
    let mut ranges = Vec::with_capacity(VISUALIZER_BAR_COUNT);

    for i in 0..VISUALIZER_BAR_COUNT {
        let t0 = i as f32 / VISUALIZER_BAR_COUNT as f32;
        let t1 = (i + 1) as f32 / VISUALIZER_BAR_COUNT as f32;
        let f0 = MIN_FREQ_HZ * (log_span * t0).exp();
        let f1 = MIN_FREQ_HZ * (log_span * t1).exp();
        let mut start = ((f0 * fft_size as f32 / sample_rate as f32).floor() as usize)
            .clamp(1, complex_len.saturating_sub(1));
        let mut end = ((f1 * fft_size as f32 / sample_rate as f32).ceil() as usize)
            .clamp(start + 1, complex_len);
        // Very low bands can collapse onto one bin at small FFT sizes. Keep
        // each bar non-empty so it can still show that bin's energy.
        if end <= start {
            start = start.min(complex_len.saturating_sub(1));
            end = (start + 1).min(complex_len);
        }
        ranges.push((start, end));
    }
    ranges
}

#[cfg(test)]
mod tests {
    use super::*;

    fn push_sine(tap: &VisualizerTap, frequency: f32, seconds: f32, sample_rate: u32) {
        let frames = (sample_rate as f32 * seconds) as usize;
        let mut samples = Vec::with_capacity(frames * 2);
        for i in 0..frames {
            let phase =
                2.0 * std::f32::consts::PI * frequency * i as f32 / sample_rate as f32;
            let sample = phase.sin() * 0.8;
            samples.push(sample);
            samples.push(sample);
        }
        tap.push(&samples, 2);
    }

    fn expected_bar(frequency: f32, sample_rate: u32) -> usize {
        let max_freq = MAX_FREQ_HZ.min(sample_rate as f32 / 2.0);
        let t = (frequency / MIN_FREQ_HZ).ln() / (max_freq / MIN_FREQ_HZ).ln();
        (t * VISUALIZER_BAR_COUNT as f32).floor() as usize
    }

    fn peak_bar(frame: &VisualizerFrame) -> usize {
        frame
            .bars
            .iter()
            .enumerate()
            .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
            .map(|(index, _)| index)
            .unwrap()
    }

    #[test]
    fn silence_stays_at_the_floor() {
        let tap = VisualizerTap::new(48_000, 2);
        tap.set_active(true);
        tap.push(&vec![0.0; 8192], 2);
        let frame = tap.frame().expect("silence should still produce a frame");
        assert!(frame.bars.iter().all(|bar| *bar < 0.05));
    }

    #[test]
    fn one_khz_sine_peaks_in_the_expected_band() {
        let tap = VisualizerTap::new(48_000, 2);
        tap.set_active(true);
        push_sine(&tap, 1_000.0, 0.12, 48_000);
        let frame = tap.frame().expect("sine should produce a frame");
        let peak = peak_bar(&frame);
        let expected = expected_bar(1_000.0, 48_000);
        assert!(
            peak.abs_diff(expected) <= 2,
            "peak bar {peak}, expected around {expected}: {:?}",
            frame.bars
        );
        assert!(frame.bars[peak] > 0.4, "sine peak too weak: {:?}", frame.bars);
    }

    #[test]
    fn a_sweep_moves_the_peak_upward() {
        let low = VisualizerTap::new(48_000, 2);
        low.set_active(true);
        push_sine(&low, 150.0, 0.12, 48_000);
        let low_peak = peak_bar(&low.frame().unwrap());

        let high = VisualizerTap::new(48_000, 2);
        high.set_active(true);
        push_sine(&high, 8_000.0, 0.12, 48_000);
        let high_peak = peak_bar(&high.frame().unwrap());

        assert!(
            high_peak > low_peak,
            "sweep peak did not move: low={low_peak}, high={high_peak}"
        );
    }

    #[test]
    fn no_data_returns_none() {
        let tap = VisualizerTap::new(48_000, 2);
        tap.set_active(true);
        assert!(tap.frame().is_none());
    }

    #[test]
    fn inactive_tap_returns_none_and_ignores_push() {
        let tap = VisualizerTap::new(48_000, 2);
        let mut samples = vec![0.5; 4096];
        tap.push(&samples, 2);
        assert!(tap.frame().is_none());
        tap.set_active(true);
        assert!(tap.frame().is_none());
        samples.fill(0.25);
        tap.push(&samples, 2);
        assert!(tap.frame().is_some());
    }

    #[test]
    fn tap_does_not_modify_audio() {
        let tap = VisualizerTap::new(48_000, 2);
        tap.set_active(true);
        let samples: Vec<f32> = (0..4096)
            .map(|i| (i as f32 * 0.01).sin() * 0.5)
            .collect();
        let original = samples.clone();
        tap.push(&samples, 2);
        assert_eq!(samples, original);
    }

    #[test]
    fn repeated_frames_without_new_audio_are_stable() {
        let tap = VisualizerTap::new(48_000, 2);
        tap.set_active(true);
        push_sine(&tap, 1_000.0, 0.12, 48_000);
        let first = tap.frame().unwrap();
        let second = tap.frame().unwrap();
        assert_eq!(first.sequence, second.sequence);
        assert_eq!(first.bars, second.bars);
    }

    #[test]
    fn sequence_advances_with_new_blocks() {
        let tap = VisualizerTap::new(48_000, 2);
        tap.set_active(true);
        tap.push(&vec![0.1; 4096], 2);
        let first = tap.frame().unwrap().sequence;
        tap.push(&vec![0.1; 4096], 2);
        let second = tap.frame().unwrap().sequence;
        assert!(second > first);
    }

    #[test]
    fn bar_ranges_cover_the_spectrum_without_empty_bands() {
        for sample_rate in [8_000, 44_100, 48_000, 96_000, 192_000] {
            let fft_size = fft_size_for(sample_rate);
            let ranges = band_ranges(sample_rate, fft_size, fft_size / 2 + 1);
            assert_eq!(ranges.len(), VISUALIZER_BAR_COUNT);
            assert!(ranges.iter().all(|(start, end)| start < end));
            assert!(ranges.windows(2).all(|pair| pair[0].0 <= pair[1].0));
        }
    }
}
