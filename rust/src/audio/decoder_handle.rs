use crate::audio::decoder::DecoderThread;
use crate::audio::dsd_engine::DsdDecoderThread;
use crate::audio::wavpack_thread::WavpackDecoderThread;
use anyhow::Result;

pub enum DecoderHandle {
    Symphonia(DecoderThread),
    Dsd(DsdDecoderThread),
    WavpackPcm(WavpackDecoderThread),
}

impl DecoderHandle {
    pub fn stop(&self) {
        match self {
            DecoderHandle::Symphonia(d) => d.stop(),
            DecoderHandle::Dsd(d) => d.stop(),
            DecoderHandle::WavpackPcm(d) => d.stop(),
        }
    }

    pub fn is_running(&self) -> bool {
        match self {
            DecoderHandle::Symphonia(d) => d.is_running(),
            DecoderHandle::Dsd(d) => d.is_running(),
            DecoderHandle::WavpackPcm(d) => d.is_running(),
        }
    }

    pub fn join(self) -> Result<()> {
        match self {
            DecoderHandle::Symphonia(d) => d.join().map_err(|e| anyhow::anyhow!("{}", e)),
            DecoderHandle::Dsd(d) => d.join(),
            DecoderHandle::WavpackPcm(d) => d.join(),
        }
    }

    pub fn is_dsd(&self) -> bool {
        matches!(self, DecoderHandle::Dsd(_))
    }
}

#[derive(Debug)]
pub enum FileType {
    Standard,
    Dsd,
    WavPack,
}

pub fn detect_file_type(path: &std::path::Path) -> FileType {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_ascii_lowercase())
        .unwrap_or_default();

    match ext.as_str() {
        "dsf" | "dff" => FileType::Dsd,
        "wv" => {
            if crate::audio::wavpack_thread::is_wavpack_dsd(path) {
                FileType::Dsd
            } else {
                FileType::WavPack
            }
        }
        _ => FileType::Standard,
    }
}
