mod database;
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
mod hybrid;
#[cfg(all(test, any(target_os = "linux", target_os = "macos", target_os = "windows")))]
mod tests;
mod two_phase;
mod types;
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
mod watcher;

pub use database::SharedFileDatabase;
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
pub use hybrid::HybridScanner;
pub use two_phase::TwoPhaseScanner;
pub use types::{ChangeKind, DbWriteBatch, FileFingerprint, ScanDiff, WatchBatch, WatchChange};
#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
pub use watcher::EventDrivenScanner;
