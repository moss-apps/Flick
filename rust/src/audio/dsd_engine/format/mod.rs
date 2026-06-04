pub mod dff_decoder;
pub mod dsf_decoder;
pub mod wavpack_decoder;

use anyhow::Result;
use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DsdChannelLayout {
    SequentialBlocks { block_size: usize },
    Interleaved,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DsdBitOrder {
    LsbFirst,
    MsbFirst,
}

pub trait DsdFormatDecoder: Send {
    fn sample_rate(&self) -> u32;
    fn channels(&self) -> u16;
    fn total_samples(&self) -> u64;
    fn duration_secs(&self) -> f64;
    fn seek(&mut self, sample: u64) -> Result<()>;
    fn read_dsd_bytes(&mut self, buf: &mut [u8]) -> Result<usize>;
    fn is_finished(&self) -> bool;
    fn channel_layout(&self) -> DsdChannelLayout;
    fn bit_order(&self) -> DsdBitOrder;
}

pub fn open_dsd_decoder(path: &Path) -> Result<Box<dyn DsdFormatDecoder>> {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();

    match ext.as_str() {
        "dsf" => {
            let decoder = dsf_decoder::DsfDecoder::open(path)?;
            Ok(Box::new(decoder))
        }
        "dff" => {
            let decoder = dff_decoder::DffDecoder::open(path)?;
            Ok(Box::new(decoder))
        }
        "wv" => {
            let decoder = wavpack_decoder::WavpackDsdDecoder::open(path)?;
            Ok(Box::new(decoder))
        }
        _ => anyhow::bail!("Unsupported DSD format: {}", ext),
    }
}
