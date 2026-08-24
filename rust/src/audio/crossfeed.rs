//! Classic BS2B (Bauer stereophonic-to-binaural) crossfeed.
//!
//! Ported from the canonical C implementation (bs2b by M. Boehme — "Bauer
//! stereophonic-to-binaural" per K.G. Bauer's patent). The 3-stage circuit per
//! channel is:
//!
//! 1. own-channel high-pass stage (`hi`)
//! 2. opposite-channel low-pass stage (`lo`)
//! 3. cross-sum stage: `L_out = hi(L) + lo(R)`, `R_out = hi(R) + lo(L)`
//!
//! The preset tables (cut frequencies, filter gains, and the DC-normalizing
//! `g = 1/(1 - G_hi + G_lo)`) are the published BS2B values, so the
//! frequency/amount balance matches the reference filters. Three active presets
//! are exposed: Default (middle crossfeed), Crossfeed (strongest), and
//! Crossfeed easy (gentle). `Off` fully bypasses processing per buffer.
//!
//! Processing is f32, deterministic, in-place on interleaved stereo buffers.
//! Parameters are recomputed only from the command thread (`set_level` /
//! `rebind_sample_rate`); `process` only reads.

use std::f32::consts::TAU;

/// Crossfeed presets, mirroring the classic BS2B levels.
///
/// Numeric values are the Dart-side index (see `audio_set_crossfeed`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum CrossfeedLevel {
    /// Crossfeed off — processing is bypassed.
    Off = 0,
    /// Middle crossfeed level (the BS2B default).
    Default = 1,
    /// High crossfeed level — strongest speaker-like blend.
    Crossfeed = 2,
    /// Middle "easy" crossfeed level — a gentler blend.
    CrossfeedEasy = 3,
}

impl CrossfeedLevel {
    pub fn from_u8(value: u8) -> Self {
        match value {
            1 => Self::Default,
            2 => Self::Crossfeed,
            3 => Self::CrossfeedEasy,
            _ => Self::Off,
        }
    }

    #[inline]
    pub fn is_active(self) -> bool {
        self != Self::Off
    }

    fn preset(self) -> (f32, f32, f32, f32) {
        match self {
            Self::Default => (500.0, 711.0, 0.459_726_988_530_872, 0.228_208_484_414_988),
            Self::Crossfeed => (700.0, 1021.0, 0.530_884_444_230_988, 0.250_105_790_667_544),
            Self::CrossfeedEasy => (500.0, 689.0, 0.354_813_389_233_575, 0.187_169_483_835_901),
            Self::Off => (500.0, 711.0, 0.459_726_988_530_872, 0.228_208_484_414_988),
        }
    }
}

/// Per-preset filter coefficients, computed for one sample rate.
#[derive(Debug, Clone, Copy)]
pub struct CrossfeedParams {
    a0_lo: f32,
    b1_lo: f32,
    a0_hi: f32,
    a1_hi: f32,
    b1_hi: f32,
}

impl CrossfeedParams {
    fn for_level(level: CrossfeedLevel, sample_rate: f32) -> Self {
        let (fc_lo, fc_hi, g_lo, g_hi) = level.preset();
        let g = 1.0 / (1.0 - g_hi + g_lo);
        let b1_lo = (-TAU * fc_lo / sample_rate).exp();
        let a0_lo = g_lo * (1.0 - b1_lo) * g;
        let b1_hi = (-TAU * fc_hi / sample_rate).exp();
        let a0_hi = (1.0 - g_hi * (1.0 - b1_hi)) * g;
        let a1_hi = -b1_hi * g;
        Self {
            a0_lo,
            b1_lo,
            a0_hi,
            a1_hi,
            b1_hi,
        }
    }
}

/// One-pole filter state plus preset level.
#[derive(Debug, Clone, Copy)]
pub struct Crossfeed {
    sample_rate: u32,
    level: CrossfeedLevel,
    params: CrossfeedParams,
    // Filter states: z for low-pass and high-pass of each channel.
    lo_l: f32,
    lo_r: f32,
    hi_l: f32,
    hi_r: f32,
}

impl Crossfeed {
    pub fn new(sample_rate: u32) -> Self {
        let params = CrossfeedParams::for_level(CrossfeedLevel::Default, sample_rate as f32);
        Self {
            sample_rate,
            level: CrossfeedLevel::Off,
            params,
            lo_l: 0.0,
            lo_r: 0.0,
            hi_l: 0.0,
            hi_r: 0.0,
        }
    }

    pub fn level(&self) -> CrossfeedLevel {
        self.level
    }

    /// Set the preset. Called from the command thread.
    pub fn set_level(&mut self, level: CrossfeedLevel) {
        if level != self.level {
            self.params = CrossfeedParams::for_level(level, self.sample_rate as f32);
        }
        self.level = level;
        if !level.is_active() {
            self.reset_state();
        }
    }

    /// Rebind to a new output sample rate, preserving the preset — the
    /// coefficients must be recomputed or the filters shift in pitch (e.g.
    /// 48k → 44.1k during a stream reopen).
    pub fn rebind_sample_rate(&mut self, sample_rate: u32) {
        let level = self.level;
        self.sample_rate = sample_rate;
        self.params = CrossfeedParams::for_level(level, sample_rate as f32);
    }

    #[inline]
    fn reset_state(&mut self) {
        self.lo_l = 0.0;
        self.lo_r = 0.0;
        self.hi_l = 0.0;
        self.hi_r = 0.0;
    }

    /// Process interleaved stereo buffer in place.
    pub fn process(&mut self, buf: &mut [f32], channels: usize) {
        if !self.level.is_active() || channels != 2 {
            return;
        }
        let p = self.params;
        let mut lo_l = self.lo_l;
        let mut lo_r = self.lo_r;
        let mut hi_l = self.hi_l;
        let mut hi_r = self.hi_r;

        for frame in buf.chunks_exact_mut(2) {
            let l = frame[0];
            let r = frame[1];

            let l_lo = p.a0_lo * l + lo_l;
            lo_l = p.b1_lo * l_lo;
            let l_hi = p.a0_hi * l + hi_l;
            hi_l = p.a1_hi * l + p.b1_hi * l_hi;

            let r_lo = p.a0_lo * r + lo_r;
            lo_r = p.b1_lo * r_lo;
            let r_hi = p.a0_hi * r + hi_r;
            hi_r = p.a1_hi * r + p.b1_hi * r_hi;

            frame[0] = l_hi + r_lo;
            frame[1] = r_hi + l_lo;
        }

        self.lo_l = lo_l;
        self.lo_r = lo_r;
        self.hi_l = hi_l;
        self.hi_r = hi_r;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn off_leaves_buffer_unchanged() {
        let mut cf = Crossfeed::new(48_000);
        let mut buf = [0.25f32, -0.25, 0.5, -0.5];
        let original = buf;

        cf.process(&mut buf, 2);

        assert_eq!(buf, original);
    }

    #[test]
    fn non_stereo_skips_processing() {
        let mut cf = Crossfeed::new(48_000);
        cf.set_level(CrossfeedLevel::Default);
        let mut mono = [0.25f32, -0.25, 0.5, -0.5];
        let original = mono;

        cf.process(&mut mono, 1);

        assert_eq!(mono, original);
    }

    #[test]
    fn dc_gain_is_unity_for_default_preset() {
        // L=R=DC: L_out = hi(L) + lo(R) with each path at unity at DC after
        // the g normalization: (1 - G_hi)*g + G_lo*g = 1.
        let mut cf = Crossfeed::new(48_000);
        cf.set_level(CrossfeedLevel::Default);

        let mut buf = vec![1.0f32; 48_000 * 2];
        cf.process(&mut buf, 2);

        let l = buf[buf.len() - 2];
        let r = buf[buf.len() - 1];
        assert!((l - 1.0).abs() < 1e-3, "left got {l}");
        assert!((r - 1.0).abs() < 1e-3, "right got {r}");
    }

    #[test]
    fn higher_level_crossfeeds_more() {
        // L=1, R=0: the right channel receives lo(L). Steady state
        // lo output = G_lo * g, preset-dependent: easy < default < crossfeed.
        let expected_crossfeed = |level: CrossfeedLevel| {
            let (_, _, g_lo, g_hi) = level.preset();
            g_lo / (1.0 - g_hi + g_lo)
        };
        let mut buf = vec![0.0f32; 48_000 * 2];
        for frame in buf.chunks_exact_mut(2) {
            frame[0] = 1.0;
            frame[1] = 0.0;
        }

        let steady = |level: CrossfeedLevel| {
            let mut cf = Crossfeed::new(48_000);
            cf.set_level(level);
            let mut b = buf.clone();
            cf.process(&mut b, 2);
            b[b.len() - 1]
        };

        let easy = steady(CrossfeedLevel::CrossfeedEasy);
        let def = steady(CrossfeedLevel::Default);
        let high = steady(CrossfeedLevel::Crossfeed);

        assert!((easy - expected_crossfeed(CrossfeedLevel::CrossfeedEasy)).abs() < 1e-3);
        assert!((def - expected_crossfeed(CrossfeedLevel::Default)).abs() < 1e-3);
        assert!((high - expected_crossfeed(CrossfeedLevel::Crossfeed)).abs() < 1e-3);
        assert!(high > def, "high {high} must exceed default {def}");
        assert!(def > easy, "default {def} must exceed easy {easy}");
    }

    #[test]
    fn left_only_signal_generates_right_crossfeed() {
        let mut cf = Crossfeed::new(48_000);
        cf.set_level(CrossfeedLevel::Default);

        let mut buf = vec![0.0f32; 2048 * 2];
        for frame in buf.chunks_exact_mut(2) {
            frame[0] = 1.0;
        }
        cf.process(&mut buf, 2);

        assert!(buf.iter().skip(1).step_by(2).any(|s| s.abs() > 1e-4));
    }

    #[test]
    fn rebind_preserves_level_and_recomputes_params() {
        let mut cf = Crossfeed::new(48_000);
        cf.set_level(CrossfeedLevel::Crossfeed);

        cf.rebind_sample_rate(44_100);

        assert_eq!(cf.level(), CrossfeedLevel::Crossfeed);

        // Params must equal a freshly built Crossfeed at the new rate.
        let fresh = Crossfeed::new(44_100);
        let mut f2 = fresh;
        f2.set_level(CrossfeedLevel::Crossfeed);
        let f2_params = f2.params;
        assert_eq!(cf.params.a0_lo, f2_params.a0_lo);
        assert_eq!(cf.params.b1_hi, f2_params.b1_hi);
    }

    #[test]
    fn from_u8_maps_levels() {
        assert_eq!(CrossfeedLevel::from_u8(0), CrossfeedLevel::Off);
        assert_eq!(CrossfeedLevel::from_u8(1), CrossfeedLevel::Default);
        assert_eq!(CrossfeedLevel::from_u8(2), CrossfeedLevel::Crossfeed);
        assert_eq!(CrossfeedLevel::from_u8(3), CrossfeedLevel::CrossfeedEasy);
        assert_eq!(CrossfeedLevel::from_u8(9), CrossfeedLevel::Off);
    }
}
