//! Equal-power crossfade implementation.
//!
//! Uses sine/cosine curves to maintain constant perceived loudness during
//! the transition between tracks.

use std::f32::consts::FRAC_PI_2;

/// Crossfade curve types.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CrossfadeCurve {
    /// Equal power using sin/cos (recommended)
    /// Maintains constant perceived loudness
    EqualPower,
    /// Linear fade (can sound "dipped" in the middle)
    Linear,
    /// Square root curve (alternative equal power)
    SquareRoot,
    /// S-curve for smoother transitions
    SCurve,
}

impl Default for CrossfadeCurve {
    fn default() -> Self {
        Self::EqualPower
    }
}

/// Crossfader state machine.
#[derive(Debug, Clone)]
pub struct Crossfader {
    /// Whether crossfade is enabled
    enabled: bool,
    /// Duration of crossfade in samples (the active fade length, possibly
    /// clamped per-track for short sources).
    duration_samples: usize,
    /// The user-configured duration in samples. Used as the end-of-track
    /// trigger threshold and as the unclamped fade length for long tracks.
    configured_duration_samples: usize,
    /// Current position in the crossfade (0 to duration_samples)
    position: usize,
    /// Whether a crossfade is currently in progress
    active: bool,
    /// The curve type to use
    curve: CrossfadeCurve,
    /// Sample rate for timing calculations
    sample_rate: u32,
}

impl Crossfader {
    /// Create a new crossfader.
    ///
    /// # Arguments
    /// * `sample_rate` - Audio sample rate (e.g., 48000)
    /// * `duration_secs` - Crossfade duration in seconds (e.g., 3.0)
    pub fn new(sample_rate: u32, duration_secs: f32) -> Self {
        let duration_samples = (sample_rate as f32 * duration_secs) as usize;
        Self {
            enabled: true,
            duration_samples,
            configured_duration_samples: duration_samples,
            position: 0,
            active: false,
            curve: CrossfadeCurve::default(),
            sample_rate,
        }
    }

    /// Create a disabled crossfader.
    pub fn disabled(sample_rate: u32) -> Self {
        Self {
            enabled: false,
            duration_samples: 0,
            configured_duration_samples: 0,
            position: 0,
            active: false,
            curve: CrossfadeCurve::default(),
            sample_rate,
        }
    }

    /// Check if crossfade is enabled.
    #[inline]
    pub fn is_enabled(&self) -> bool {
        self.enabled
    }

    /// Check if a crossfade is currently active.
    #[inline]
    pub fn is_active(&self) -> bool {
        self.active
    }

    /// Current crossfade position (frame count).
    #[inline]
    pub fn position(&self) -> usize {
        self.position
    }

    /// Crossfade duration in frames.
    #[inline]
    pub fn duration_samples(&self) -> usize {
        self.duration_samples
    }

    /// Enable or disable crossfade.
    pub fn set_enabled(&mut self, enabled: bool) {
        self.enabled = enabled;
        if !enabled {
            self.active = false;
            self.position = 0;
        }
    }

    /// Set the crossfade duration.
    ///
    /// Resets both the configured (threshold) and active (fade length)
    /// durations to the user preference.
    pub fn set_duration(&mut self, duration_secs: f32) {
        let samples = (self.sample_rate as f32 * duration_secs) as usize;
        self.duration_samples = samples;
        self.configured_duration_samples = samples;
    }

    /// The user-configured duration in seconds. Used by the engine as the
    /// end-of-track trigger threshold and as the fade length when the track
    /// is long enough.
    #[inline]
    pub fn configured_duration_secs(&self) -> f32 {
        self.configured_duration_samples as f32 / self.sample_rate as f32
    }

    /// Set the active fade length for the upcoming crossfade, independently of
    /// the configured duration. The engine clamps this to half the current
    /// track's length for short sources. Should only be called immediately
    /// before [`start`]. Leaves the configured duration untouched so the next
    /// track recomputes its clamp from the user preference.
    ///
    /// [`start`]: Crossfader::start
    pub fn set_active_duration_secs(&mut self, duration_secs: f32) {
        self.duration_samples = (self.sample_rate as f32 * duration_secs) as usize;
    }

    /// Rebind to a new output sample rate, preserving the enabled state,
    /// configured duration (in seconds), and curve. Any in-progress fade is
    /// cancelled. Called by `reconfigure_sample_rate` so a mid-session
    /// output-rate change (e.g. 48k → 44.1k during Oboe stream open) does not
    /// silently wipe the user's crossfade preference.
    pub fn rebind_sample_rate(&mut self, sample_rate: u32) {
        let configured_secs = self.configured_duration_secs();
        self.sample_rate = sample_rate;
        let samples = (sample_rate as f32 * configured_secs) as usize;
        self.configured_duration_samples = samples;
        self.duration_samples = samples;
        self.active = false;
        self.position = 0;
    }

    /// Get the crossfade duration in seconds.
    pub fn duration_secs(&self) -> f32 {
        self.duration_samples as f32 / self.sample_rate as f32
    }

    /// Get remaining crossfade time in seconds.
    pub fn remaining_secs(&self) -> f32 {
        if !self.active {
            return 0.0;
        }
        let remaining_samples = self.duration_samples.saturating_sub(self.position);
        remaining_samples as f32 / self.sample_rate as f32
    }

    /// Set the curve type.
    pub fn set_curve(&mut self, curve: CrossfadeCurve) {
        self.curve = curve;
    }

    /// Start a crossfade transition.
    pub fn start(&mut self) {
        if self.enabled && self.duration_samples > 0 {
            self.active = true;
            self.position = 0;
        }
    }

    /// Reset the crossfader (cancel any active crossfade).
    pub fn reset(&mut self) {
        self.active = false;
        self.position = 0;
    }

    /// Calculate gains for the current position.
    ///
    /// Returns (gain_a, gain_b) where:
    /// - gain_a is the fading-out track's volume
    /// - gain_b is the fading-in track's volume
    #[inline]
    pub fn current_gains(&self) -> (f32, f32) {
        if !self.active || self.duration_samples == 0 {
            // No crossfade: track A at full volume, track B silent
            return (1.0, 0.0);
        }

        let progress = (self.position as f32 / self.duration_samples as f32).clamp(0.0, 1.0);
        self.calculate_gains(progress)
    }

    /// Calculate gains for a given progress value (0.0 to 1.0).
    #[inline]
    fn calculate_gains(&self, progress: f32) -> (f32, f32) {
        match self.curve {
            CrossfadeCurve::EqualPower => {
                // Equal power crossfade using sin/cos
                // At progress=0: A=1, B=0
                // At progress=0.5: A≈0.707, B≈0.707 (constant power)
                // At progress=1: A=0, B=1
                let angle = progress * FRAC_PI_2;
                let gain_a = angle.cos();
                let gain_b = angle.sin();
                (gain_a, gain_b)
            }
            CrossfadeCurve::Linear => {
                // Simple linear crossfade
                let gain_a = 1.0 - progress;
                let gain_b = progress;
                (gain_a, gain_b)
            }
            CrossfadeCurve::SquareRoot => {
                // Square root curve (alternative equal power)
                let gain_a = (1.0 - progress).sqrt();
                let gain_b = progress.sqrt();
                (gain_a, gain_b)
            }
            CrossfadeCurve::SCurve => {
                // S-curve (smooth start and end)
                // Using smoothstep: 3x² - 2x³
                let s = progress * progress * (3.0 - 2.0 * progress);
                let gain_a = 1.0 - s;
                let gain_b = s;
                (gain_a, gain_b)
            }
        }
    }

    /// Advance the crossfade by one sample.
    /// Returns true if the crossfade just completed.
    #[inline]
    pub fn advance(&mut self) -> bool {
        if !self.active {
            return false;
        }

        self.position += 1;
        if self.position >= self.duration_samples {
            self.active = false;
            self.position = 0;
            return true;
        }
        false
    }

    /// Advance the crossfade by multiple samples.
    /// Returns true if the crossfade completed during this advance.
    #[inline]
    pub fn advance_by(&mut self, samples: usize) -> bool {
        if !self.active {
            return false;
        }

        self.position += samples;
        if self.position >= self.duration_samples {
            self.active = false;
            self.position = 0;
            return true;
        }
        false
    }

    /// Mix two audio buffers according to current crossfade state.
    ///
    /// This is the main mixing function called during crossfade.
    /// It advances the crossfade position automatically.
    ///
    /// # Arguments
    /// * `source_a` - Samples from the outgoing track
    /// * `source_b` - Samples from the incoming track
    /// * `output` - Pre-allocated output buffer
    /// * `channels` - Number of audio channels (for proper gain application)
    ///
    /// # Returns
    /// * `Ok(true)` if crossfade completed during this mix
    /// * `Ok(false)` if crossfade is still in progress
    pub fn mix(
        &mut self,
        source_a: &[f32],
        source_b: &[f32],
        output: &mut [f32],
        channels: usize,
    ) -> Result<bool, String> {
        let samples = source_a.len().min(source_b.len()).min(output.len());
        let frames = samples / channels;

        if frames == 0 {
            return Ok(false);
        }

        let mut completed = false;

        // Process frame by frame for smooth gain transitions
        for frame in 0..frames {
            let (gain_a, gain_b) = self.current_gains();

            for ch in 0..channels {
                let idx = frame * channels + ch;
                if idx < samples {
                    // Mix with gains: output = (A * gainA) + (B * gainB)
                    let sample_a = source_a.get(idx).copied().unwrap_or(0.0);
                    let sample_b = source_b.get(idx).copied().unwrap_or(0.0);
                    output[idx] = sample_a * gain_a + sample_b * gain_b;
                }
            }

            if self.advance() {
                completed = true;
            }
        }

        Ok(completed)
    }

    /// Apply fade-out to a single buffer (no mixing, just gain reduction).
    pub fn apply_fadeout(&mut self, buffer: &mut [f32], channels: usize) {
        if !self.active {
            return;
        }

        let frames = buffer.len() / channels;
        for frame in 0..frames {
            let (gain_a, _) = self.current_gains();
            for ch in 0..channels {
                let idx = frame * channels + ch;
                if idx < buffer.len() {
                    buffer[idx] *= gain_a;
                }
            }
            self.advance();
        }
    }

    /// Apply fade-in to a single buffer (no mixing, just gain increase).
    pub fn apply_fadein(&mut self, buffer: &mut [f32], channels: usize) {
        if !self.active {
            return;
        }

        let frames = buffer.len() / channels;
        for frame in 0..frames {
            let (_, gain_b) = self.current_gains();
            for ch in 0..channels {
                let idx = frame * channels + ch;
                if idx < buffer.len() {
                    buffer[idx] *= gain_b;
                }
            }
            self.advance();
        }
    }
}

/// SIMD-optimized mixing for larger buffers.
///
/// This function processes samples in chunks for better cache utilization
/// and potential auto-vectorization.
#[inline]
pub fn mix_buffers_with_gains(
    source_a: &[f32],
    gain_a: f32,
    source_b: &[f32],
    gain_b: f32,
    output: &mut [f32],
) {
    let len = source_a.len().min(source_b.len()).min(output.len());

    // Process in chunks of 8 for potential SIMD optimization
    let chunks = len / 8;
    let remainder = len % 8;

    for i in 0..chunks {
        let base = i * 8;
        for j in 0..8 {
            let idx = base + j;
            output[idx] = source_a[idx] * gain_a + source_b[idx] * gain_b;
        }
    }

    // Handle remaining samples
    let base = chunks * 8;
    for j in 0..remainder {
        let idx = base + j;
        output[idx] = source_a[idx] * gain_a + source_b[idx] * gain_b;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_equal_power_at_midpoint() {
        let crossfader = Crossfader::new(48000, 1.0);

        // At midpoint (progress = 0.5), both gains should be ~0.707
        let (gain_a, gain_b) = crossfader.calculate_gains(0.5);

        // Equal power means A² + B² = 1
        let power_sum = gain_a * gain_a + gain_b * gain_b;
        assert!((power_sum - 1.0).abs() < 0.01, "Power sum: {}", power_sum);
    }

    #[test]
    fn test_crossfade_start_end() {
        let crossfader = Crossfader::new(48000, 1.0);

        // At start: A=1, B=0
        let (gain_a, gain_b) = crossfader.calculate_gains(0.0);
        assert!((gain_a - 1.0).abs() < 0.001);
        assert!(gain_b.abs() < 0.001);

        // At end: A=0, B=1
        let (gain_a, gain_b) = crossfader.calculate_gains(1.0);
        assert!(gain_a.abs() < 0.001);
        assert!((gain_b - 1.0).abs() < 0.001);
    }

    #[test]
    fn test_crossfade_progression() {
        let mut crossfader = Crossfader::new(48000, 1.0);
        crossfader.start();

        assert!(crossfader.is_active());

        // Advance through the entire crossfade
        for _ in 0..48000 {
            if crossfader.advance() {
                break;
            }
        }

        assert!(!crossfader.is_active());
    }

    #[test]
    fn test_configured_duration_independent_of_active_clamp() {
        let mut crossfader = Crossfader::new(48000, 5.0);
        // Configured duration reflects the user preference.
        assert!((crossfader.configured_duration_secs() - 5.0).abs() < 0.01);

        // Engine clamps the active fade to 1.0s for a short track.
        crossfader.set_active_duration_secs(1.0);
        assert!((crossfader.duration_secs() - 1.0).abs() < 0.01);
        // Configured duration must be untouched so the next track recomputes.
        assert!((crossfader.configured_duration_secs() - 5.0).abs() < 0.01);

        crossfader.start();
        assert!(crossfader.is_active());
        // Active fade runs for the clamped 1s (48000 samples), not 5s.
        for _ in 0..48000 {
            if crossfader.advance() {
                break;
            }
        }
        assert!(!crossfader.is_active());
    }

    #[test]
    fn test_set_duration_resets_configured_and_active() {
        let mut crossfader = Crossfader::new(48000, 1.0);
        crossfader.set_active_duration_secs(0.5);
        crossfader.set_duration(3.0);
        assert!((crossfader.configured_duration_secs() - 3.0).abs() < 0.01);
        assert!((crossfader.duration_secs() - 3.0).abs() < 0.01);
    }

    #[test]
    fn test_rebind_sample_rate_preserves_state() {
        let mut crossfader = Crossfader::new(48000, 4.0);
        crossfader.set_curve(CrossfadeCurve::Linear);
        crossfader.start();
        assert!(crossfader.is_active());

        // A mid-session output-rate change (e.g. 48k -> 44.1k) must NOT wipe
        // the user's enabled/duration/curve preference.
        crossfader.rebind_sample_rate(44100);

        assert!(crossfader.is_enabled());
        // Configured duration in seconds is preserved across the rate change.
        assert!((crossfader.configured_duration_secs() - 4.0).abs() < 0.05);
        // Sample counts are recomputed at the new rate.
        assert_eq!(crossfader.duration_samples(), (44100.0 * 4.0) as usize);
        // An in-progress fade is cancelled.
        assert!(!crossfader.is_active());
    }
}
