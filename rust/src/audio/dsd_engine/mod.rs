pub mod dsd;
pub mod dsd_thread;
pub mod format;
pub mod output;

pub use dsd::{DsdDecimationPipeline, DsdOutputMode, DsdRate};
pub use dsd_thread::DsdDecoderThread;
pub use format::DsdFormatDecoder;
pub use output::DsdOutputRouter;

use std::sync::atomic::{AtomicBool, Ordering};

/// Offline wire/raw capture for DSD diagnosis. Default off: the captures are
/// multi-MiB blocking writes to external storage executed inside the decode
/// and render loops, which starves the ring and injects silence gaps.
static DSD_DUMPS_ENABLED: AtomicBool = AtomicBool::new(false);

pub fn dsd_dumps_enabled() -> bool {
    DSD_DUMPS_ENABLED.load(Ordering::Relaxed)
}

#[allow(dead_code)]
pub fn set_dsd_dumps_enabled(enabled: bool) {
    DSD_DUMPS_ENABLED.store(enabled, Ordering::Relaxed);
}
