//! Direct (time-domain) convolution for impulse-response processing.
//!
//! Textbook FIR: `y[n] = Σ h[k]·x[n−k]`. Input history is held in a per-channel
//! ring buffer so the realtime callback allocates nothing after `load_ir`.
//!
//! The convolver only runs in `PipelineMode::Dsp` — passthrough/DoP branches
//! return before reaching it (it would break bit-perfect delivery).
//!
//! ponytail: O(M) direct convolution with a tap cap. Switch to partitioned FFT
//! overlap-save (rustfft + realfft) if users load long hall tails and
//! `XRUN_COUNT` climbs.

/// Maximum number of taps kept from an IR. Anything longer is truncated
/// (keeps the direct/early response). At 48 kHz this is ~341 ms of tail —
/// enough for room reverb, crossfeed, cabinet sims and correction IRs.
pub const IR_TAP_CAP: usize = 16_384;

pub struct Convolver {
    sample_rate: u32,
    enabled: bool,
    /// Wet/dry mix. 1.0 = full IR, 0.0 = dry passthrough.
    mix: f32,
    /// IR coefficients. Always length 2 after `load_ir` (mono IR is replicated
    /// to both slots); empty when no IR is loaded.
    ir: Vec<Vec<f32>>,
    /// Per-slot input-history ring buffer (length = taps). Two slots so a mono
    /// IR can still track L and R independently under stereo engine output.
    history: Vec<Vec<f32>>,
    /// Per-slot write index into `history` (next slot to overwrite = oldest).
    write_pos: Vec<usize>,
}

impl Convolver {
    pub fn new(sample_rate: u32) -> Self {
        Self {
            sample_rate,
            enabled: false,
            mix: 1.0,
            ir: Vec::new(),
            history: Vec::new(),
            write_pos: Vec::new(),
        }
    }

    pub fn reconfigure_sample_rate(&mut self, sample_rate: u32) {
        // Taps are count-rate-independent, but zero the history so a stale tail
        // from the old rate doesn't smear the first block at the new rate. The
        // IR itself is retained; a re-sample at the new rate is encouraged but
        // not forced here (cheap fallback until the loader re-runs).
        for h in &mut self.history {
            h.fill(0.0);
        }
        self.sample_rate = sample_rate;
    }

    pub fn set(&mut self, enabled: bool, mix: f32) {
        self.enabled = enabled;
        self.mix = mix.clamp(0.0, 1.0);
        if !enabled {
            self.reset_state();
        }
    }

    /// Load pre-decoded, pre-resampled, peak-normalised IR coefficients.
    /// `coeffs.len()` is 1 (mono, applied to both channels) or 2 (stereo L/R).
    /// Each inner vec is already capped to `IR_TAP_CAP` by the loader.
    pub fn load_ir(&mut self, coeffs: Vec<Vec<f32>>) {
        if coeffs.is_empty() || coeffs[0].is_empty() {
            return;
        }
        let taps = coeffs[0].len();
        let (l, r) = match coeffs.len() {
            1 => {
                let c = coeffs.into_iter().next().unwrap();
                (c.clone(), c)
            }
            _ => {
                let mut it = coeffs.into_iter();
                let l = it.next().unwrap_or_default();
                let r = it.next().unwrap_or_else(|| l.clone());
                (l, r)
            }
        };
        self.ir = vec![l, r];
        self.history = vec![vec![0.0; taps]; 2];
        self.write_pos = vec![0, 0];
    }

    pub fn clear_ir(&mut self) {
        self.ir.clear();
        self.history.clear();
        self.write_pos.clear();
        self.enabled = false;
    }

    fn reset_state(&mut self) {
        for h in &mut self.history {
            h.fill(0.0);
        }
        for w in &mut self.write_pos {
            *w = 0;
        }
    }

    pub fn process(&mut self, buf: &mut [f32], channels: usize) {
        if channels == 0 || !self.enabled || self.ir.is_empty() {
            return;
        }
        let taps = self.ir[0].len();
        if taps == 0 || self.history.len() < 2 {
            return;
        }

        let dry = 1.0 - self.mix;
        let wet = self.mix;

        for frame in buf.chunks_exact_mut(channels) {
            for ch in 0..channels {
                let slot = if ch > 0 { 1 } else { 0 };
                let dry_s = frame[ch];
                let hist = &mut self.history[slot];
                let ir = &self.ir[slot];
                let pos = self.write_pos[slot];

                // Write current sample into the ring (overwrites oldest).
                hist[pos] = dry_s;

                // y = Σ h[k]·x[n-k], walking backwards through the ring in two
                // contiguous segments to avoid a per-tap modulo.
                let mut acc = 0.0f32;
                // ponytail: O(M) MAC loop per sample; partitioned FFT if long IRs xrun.
                for k in 0..=pos {
                    acc += ir[k] * hist[pos - k];
                }
                for k in (pos + 1)..taps {
                    acc += ir[k] * hist[taps + pos - k];
                }

                self.write_pos[slot] = if pos + 1 >= taps { 0 } else { pos + 1 };

                frame[ch] = (dry_s * dry + acc * wet).clamp(-1.0, 1.0);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn disabled_leaves_buffer_unchanged() {
        let mut c = Convolver::new(48_000);
        let mut buf = [0.25f32, -0.25, 0.5, -0.5];
        let original = buf;
        c.process(&mut buf, 2);
        assert_eq!(buf, original);
    }

    #[test]
    fn no_ir_leaves_buffer_unchanged_even_when_enabled() {
        let mut c = Convolver::new(48_000);
        c.set(true, 1.0);
        let mut buf = [0.25f32, -0.25, 0.5, -0.5];
        let original = buf;
        c.process(&mut buf, 2);
        assert_eq!(buf, original);
    }

    #[test]
    fn impulse_ir_reproduces_input() {
        // A unit-impulse IR convolved at full mix is identity.
        let mut c = Convolver::new(48_000);
        c.load_ir(vec![vec![1.0, 0.0, 0.0, 0.0]]);
        c.set(true, 1.0);

        let mut buf = [0.4f32, -0.2, 0.9, 0.1, -0.7, 0.3];
        let original = buf;
        c.process(&mut buf, 2);
        for (a, b) in buf.iter().zip(original.iter()) {
            assert!((a - b).abs() < 1e-5, "{} != {}", a, b);
        }
    }

    #[test]
    fn two_tap_fir_matches_definition() {
        // y[n] = a·x[n] + b·x[n-1]
        let mut c = Convolver::new(48_000);
        c.load_ir(vec![vec![0.5, 0.25]]);
        c.set(true, 1.0);

        // An impulse input reproduces the IR: y[n]=a·x[n]+b·x[n-1] over
        // x=[1,0,0,0] gives [a, b, 0, 0] = [0.5, 0.25, 0, 0].
        let mut buf = [1.0f32, 0.0, 0.0, 0.0];
        c.process(&mut buf, 1);
        assert!((buf[0] - 0.5).abs() < 1e-5);
        assert!((buf[1] - 0.25).abs() < 1e-5);
        assert!(buf[2].abs() < 1e-5);
        assert!(buf[3].abs() < 1e-5);
    }

    #[test]
    fn mono_ir_applied_to_both_channels() {
        let mut c = Convolver::new(48_000);
        c.load_ir(vec![vec![1.0, 0.0]]);
        c.set(true, 1.0);

        let mut buf = [0.8f32, 0.8, 0.0, 0.0];
        c.process(&mut buf, 2);
        // Both channels should carry the impulse response of their own signal.
        assert!((buf[0] - 0.8).abs() < 1e-5);
        assert!((buf[1] - 0.8).abs() < 1e-5);
    }

    #[test]
    fn stereo_ir_routes_channels_independently() {
        let mut c = Convolver::new(48_000);
        // L IR scales by 0.5, R IR scales by 0.25 — full mix, impulse.
        c.load_ir(vec![vec![0.5, 0.0], vec![0.25, 0.0]]);
        c.set(true, 1.0);

        let mut buf = [1.0f32, 1.0];
        c.process(&mut buf, 2);
        assert!((buf[0] - 0.5).abs() < 1e-5);
        assert!((buf[1] - 0.25).abs() < 1e-5);
    }
}
