//! Flutter Rust Bridge API for the live visualizer.
//!
//! This is a pull API: Dart polls only while a visualizer is visible, so the
//! engine never runs an FFT or wakes a thread for an off-screen widget.

use crate::api::audio_api::{read_audio_engine, with_audio_engine};

/// One analyzed frame from the Rust PCM tap.
#[derive(Debug, Clone)]
pub struct VisualizerBars {
    /// Normalized bar heights, oldest low frequency first.
    pub bars: Vec<f32>,
    /// Output sample rate of the engine when the frame was analyzed.
    pub sample_rate: u32,
    /// Monotonic block counter used by Dart to skip duplicate frames.
    pub sequence: u64,
}

/// Return the latest spectrum, or `None` when no engine is running, the tap is
/// inactive, or fewer than one FFT window of PCM has been rendered yet.
pub fn visualizer_get_bars() -> Option<VisualizerBars> {
    read_audio_engine(|handle| {
        handle.visualizer_frame().map(|frame| VisualizerBars {
            bars: frame.bars,
            sample_rate: frame.sample_rate,
            sequence: frame.sequence,
        })
    })
    .flatten()
}

/// Enable or disable the PCM tap. Inactive capture is a single relaxed atomic
/// load per audio callback and clears any stale history.
pub fn visualizer_set_active(active: bool) -> bool {
    with_audio_engine(|handle| {
        handle.set_visualizer_active(active);
        Ok(true)
    })
    .unwrap_or(false)
}
