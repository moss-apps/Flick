use crate::audio::source::SourceProvider;
use parking_lot::Mutex;
use serde::Serialize;
use std::sync::Arc;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum BackendType {
    UsbDirect,
    DapNative,
    MixerBitPerfect,
    MixerMatched,
    ResampledFallback,
    DsdNative,
    DsdDoP,
    UsbDsdNative,
}

impl BackendType {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::UsbDirect => "usb_direct",
            Self::DapNative => "dap_native",
            Self::MixerBitPerfect => "mixer_bit_perfect",
            Self::MixerMatched => "mixer_matched",
            Self::ResampledFallback => "resampled_fallback",
            Self::DsdNative => "dsd_native",
            Self::DsdDoP => "dsd_dop",
            Self::UsbDsdNative => "usb_dsd_native",
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct BackendDescriptor {
    pub backend_type: BackendType,
    pub supports_passthrough: bool,
    pub max_sample_rate: u32,
    pub priority: u8,
}

pub trait AudioBackend: Send + Sync {
    fn start(&mut self, source_provider: Arc<Mutex<SourceProvider>>) -> Result<(), String>;
    fn stop(&mut self) -> Result<(), String>;
    fn is_active(&self) -> bool;
    fn name(&self) -> &str;
    fn descriptor(&self) -> BackendDescriptor;
}