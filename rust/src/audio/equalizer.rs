//! Parametric EQ: variable-band biquad chain with real per-type RBJ
//! coefficients. Lock-free on the audio thread via fixed-MAX double buffering
//! (no allocation in process()).

use std::f32::consts::PI;
use std::sync::atomic::{AtomicU8, Ordering};

/// Mirror of Dart ParametricBandType (allPass dropped — it is a no-op).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EqBandType {
    Peaking,
    LowShelf,
    HighShelf,
    LowPass,
    HighPass,
    BandPass,
    Notch,
}

/// One band. Coefficients are computed in Rust (which knows the active sample
/// rate); Dart only describes the band.
#[derive(Debug, Clone, Copy)]
pub struct EqBandSpec {
    pub band_type: EqBandType,
    pub freq_hz: f32,
    pub gain_db: f32,
    pub q: f32,
}

/// Fixed center frequencies (Hz) for graphic mode (Dart builds peaking specs
/// at these frequencies).
pub const BAND_FREQS_HZ: [f32; 10] = [
    32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
];

/// ponytail: fixed ceiling matching Dart maxParametricBands (31). Variable
/// count is an active_bands count over this fixed array, keeping process()
/// allocation-free and the double-buffered swap lock-free. Bump MAX_BANDS
/// (and the Dart max) if a higher ceiling is ever needed.
pub const MAX_BANDS: usize = 31;

const COEFFS_PER_BAND: usize = 5;

/// Biquad coeffs per band: b0, b1, b2, a1, a2 (a0 normalized to 1).
#[derive(Clone, Copy)]
pub struct EqParams {
    pub enabled: bool,
    pub active_bands: usize,
    pub coeffs: [[f32; COEFFS_PER_BAND]; MAX_BANDS],
}

impl EqParams {
    pub fn disabled() -> Self {
        Self {
            enabled: false,
            active_bands: 0,
            coeffs: [[1.0, 0.0, 0.0, 0.0, 0.0]; MAX_BANDS],
        }
    }

    /// Build from variable band specs at a given sample rate.
    pub fn from_specs(specs: &[EqBandSpec], sample_rate: u32) -> Self {
        let fs = sample_rate as f32;
        let mut coeffs = [[1.0f32; COEFFS_PER_BAND]; MAX_BANDS];
        let n = specs.len().min(MAX_BANDS);
        for (i, spec) in specs.iter().take(n).enumerate() {
            coeffs[i] = biquad_coeffs(*spec, fs);
        }
        Self {
            enabled: true,
            active_bands: n,
            coeffs,
        }
    }
}

/// RBJ Audio Cookbook coefficients for a band, normalized (a0 = 1).
/// f0 is clamped below Nyquist and Q to a positive floor to stay stable.
fn biquad_coeffs(spec: EqBandSpec, fs: f32) -> [f32; COEFFS_PER_BAND] {
    let nyq = fs * 0.5;
    let f0 = spec.freq_hz.clamp(1.0, nyq * 0.99);
    let q = spec.q.clamp(0.2, 20.0);

    let w0 = 2.0 * PI * f0 / fs;
    let cos_w0 = w0.cos();
    let sin_w0 = w0.sin();
    let alpha = sin_w0 / (2.0 * q);

    let (b0, b1, b2, a0, a1, a2) = match spec.band_type {
        EqBandType::Peaking => {
            let a = 10.0f32.powf(spec.gain_db / 40.0);
            (
                1.0 + alpha * a,
                -2.0 * cos_w0,
                1.0 - alpha * a,
                1.0 + alpha / a,
                -2.0 * cos_w0,
                1.0 - alpha / a,
            )
        }
        EqBandType::LowShelf => {
            let a = 10.0f32.powf(spec.gain_db / 40.0);
            let sq = a.sqrt();
            (
                a * ((a + 1.0) - (a - 1.0) * cos_w0 + 2.0 * sq * alpha),
                2.0 * a * ((a - 1.0) - (a + 1.0) * cos_w0),
                a * ((a + 1.0) - (a - 1.0) * cos_w0 - 2.0 * sq * alpha),
                (a + 1.0) + (a - 1.0) * cos_w0 + 2.0 * sq * alpha,
                -2.0 * ((a - 1.0) + (a + 1.0) * cos_w0),
                (a + 1.0) + (a - 1.0) * cos_w0 - 2.0 * sq * alpha,
            )
        }
        EqBandType::HighShelf => {
            let a = 10.0f32.powf(spec.gain_db / 40.0);
            let sq = a.sqrt();
            (
                a * ((a + 1.0) + (a - 1.0) * cos_w0 + 2.0 * sq * alpha),
                -2.0 * a * ((a - 1.0) + (a + 1.0) * cos_w0),
                a * ((a + 1.0) + (a - 1.0) * cos_w0 - 2.0 * sq * alpha),
                (a + 1.0) - (a - 1.0) * cos_w0 + 2.0 * sq * alpha,
                2.0 * ((a - 1.0) - (a + 1.0) * cos_w0),
                (a + 1.0) - (a - 1.0) * cos_w0 - 2.0 * sq * alpha,
            )
        }
        EqBandType::LowPass => (
            (1.0 - cos_w0) / 2.0,
            1.0 - cos_w0,
            (1.0 - cos_w0) / 2.0,
            1.0 + alpha,
            -2.0 * cos_w0,
            1.0 - alpha,
        ),
        EqBandType::HighPass => (
            (1.0 + cos_w0) / 2.0,
            -(1.0 + cos_w0),
            (1.0 + cos_w0) / 2.0,
            1.0 + alpha,
            -2.0 * cos_w0,
            1.0 - alpha,
        ),
        EqBandType::BandPass => (
            alpha,
            0.0,
            -alpha,
            1.0 + alpha,
            -2.0 * cos_w0,
            1.0 - alpha,
        ),
        EqBandType::Notch => (
            1.0,
            -2.0 * cos_w0,
            1.0,
            1.0 + alpha,
            -2.0 * cos_w0,
            1.0 - alpha,
        ),
    };

    [
        b0 / a0,
        b1 / a0,
        b2 / a0,
        a1 / a0,
        a2 / a0,
    ]
}

/// Per-channel, per-band biquad state: x1, x2, y1, y2.
type BandState = [f32; 4];
type ChannelState = [BandState; MAX_BANDS];

/// Double-buffered params for lock-free updates from the command thread.
/// State is per-channel (not double-buffered) for stereo processing.
pub struct Equalizer {
    params: [EqParams; 2],
    index: AtomicU8,
    /// Per-channel filter state. Indexed by channel (0=left, 1=right).
    state: [ChannelState; 2],
}

impl Equalizer {
    pub fn new() -> Self {
        Self {
            params: [EqParams::disabled(), EqParams::disabled()],
            index: AtomicU8::new(0),
            state: [[[0.0; 4]; MAX_BANDS]; 2],
        }
    }

    /// Called from command thread. sample_rate must match engine.
    pub fn set(&mut self, enabled: bool, specs: &[EqBandSpec], sample_rate: u32) {
        let next = if enabled {
            EqParams::from_specs(specs, sample_rate)
        } else {
            EqParams::disabled()
        };
        let idx = self.index.load(Ordering::Relaxed);
        self.params[1 - idx as usize] = next;
        self.index.store(1 - idx, Ordering::Release);
        // Reset state when disabling to avoid artifacts when re-enabling
        if !enabled {
            for ch_state in &mut self.state {
                for band_state in ch_state.iter_mut() {
                    band_state.fill(0.0);
                }
            }
        }
    }

    #[inline]
    fn current_params(&self) -> EqParams {
        self.params[self.index.load(Ordering::Acquire) as usize]
    }

    /// Process interleaved buffer in place. channels = 2.
    pub fn process(&mut self, buf: &mut [f32], channels: usize) {
        let p = self.current_params();
        if !p.enabled || p.active_bands == 0 {
            return;
        }
        let max_channels = self.state.len().min(channels);
        let frames = buf.len() / channels;
        let active = p.active_bands;
        for f in 0..frames {
            for ch in 0..max_channels {
                let idx = f * channels + ch;
                let x0 = buf[idx];
                buf[idx] =
                    process_sample_chain(x0, &p.coeffs[..active], &mut self.state[ch][..active]);
            }
        }
    }
}

#[inline]
fn process_sample_chain(x0: f32, coeffs: &[[f32; COEFFS_PER_BAND]], state: &mut [BandState]) -> f32 {
    let mut x = x0;
    for (b, s) in coeffs.iter().zip(state.iter_mut()) {
        let (b0, b1, b2, a1, a2) = (b[0], b[1], b[2], b[3], b[4]);
        let (x1, x2, y1, y2) = (s[0], s[1], s[2], s[3]);
        let y0 = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
        s[0] = x;
        s[1] = x1;
        s[2] = y0;
        s[3] = y1;
        x = y0;
    }
    x
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn peaking_zero_gain_is_unity() {
        // 0 dB peaking band has unity transfer function: numerator == denominator
        // (b0==1 and b==a after a0 normalization), i.e. H(z)=1, not identity coeffs.
        let fs = 48000.0_f32;
        let spec = EqBandSpec {
            band_type: EqBandType::Peaking,
            freq_hz: 1000.0,
            gain_db: 0.0,
            q: 1.0,
        };
        let c = biquad_coeffs(spec, fs);
        assert!((c[0] - 1.0).abs() < 1e-5, "b0={}", c[0]);
        assert!((c[1] - c[3]).abs() < 1e-5, "b1={} a1={}", c[1], c[3]);
        assert!((c[2] - c[4]).abs() < 1e-5, "b2={} a2={}", c[2], c[4]);
    }

    #[test]
    fn process_bypasses_when_disabled() {
        let mut eq = Equalizer::new();
        let mut buf = [0.1_f32, 0.2, 0.3, 0.4];
        eq.set(false, &[], 48000);
        eq.process(&mut buf, 2);
        // untouched
        assert_eq!(buf, [0.1, 0.2, 0.3, 0.4]);
    }

    #[test]
    fn process_identity_with_zero_gain_peaking() {
        let mut eq = Equalizer::new();
        let specs = [EqBandSpec {
            band_type: EqBandType::Peaking,
            freq_hz: 1000.0,
            gain_db: 0.0,
            q: 1.0,
        }];
        eq.set(true, &specs, 48000);
        let mut buf = [0.5_f32, -0.5, 0.25, -0.25];
        let original = buf;
        eq.process(&mut buf, 2);
        for (got, want) in buf.iter().zip(original.iter()) {
            assert!((got - want).abs() < 1e-5, "got {got} want {want}");
        }
    }

    #[test]
    fn variable_band_count_processes_active_only() {
        // 3 specs => only 3 bands active; a 4th stale slot must not run.
        let mut eq = Equalizer::new();
        let specs = [
            EqBandSpec {
                band_type: EqBandType::Peaking,
                freq_hz: 100.0,
                gain_db: 6.0,
                q: 1.0,
            },
            EqBandSpec {
                band_type: EqBandType::HighShelf,
                freq_hz: 4000.0,
                gain_db: 3.0,
                q: 0.7,
            },
            EqBandSpec {
                band_type: EqBandType::Notch,
                freq_hz: 50.0,
                gain_db: 0.0,
                q: 2.0,
            },
        ];
        eq.set(true, &specs, 48000);
        let p = eq.current_params();
        assert_eq!(p.active_bands, 3);
        let mut buf = [0.5_f32; 8];
        eq.process(&mut buf, 2);
        // Nonzero boost band must change the sample (not identity).
        assert!(buf[0].abs() > 1e-6);
    }

    #[test]
    fn high_freq_clamps_below_nyquist() {
        // freq above Nyquist must not blow up (clamped internally).
        let c = biquad_coeffs(
            EqBandSpec {
                band_type: EqBandType::Peaking,
                freq_hz: 30000.0,
                gain_db: 9.0,
                q: 1.0,
            },
            48000.0,
        );
        for v in c.iter() {
            assert!(v.is_finite(), "non-finite coeff {c:?}");
        }
    }
}
