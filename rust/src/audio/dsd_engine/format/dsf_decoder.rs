use super::{DsdBitOrder, DsdChannelLayout, DsdFormatDecoder};
use anyhow::{anyhow, Result};
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;

pub struct DsfDecoder {
    file: File,
    sample_rate: u32,
    channels: u16,
    total_samples: u64,
    data_offset: u64,
    block_size: u32,
    current_position: u64,
    bit_order: DsdBitOrder,
    finished: bool,
}

impl DsfDecoder {
    pub fn open(path: &Path) -> Result<Self> {
        let dsf = dsf_meta::DsfFile::open(path)
            .map_err(|e| anyhow!("Failed to parse DSF header: {}", e))?;

        let fmt = dsf.fmt_chunk();
        let sample_rate = fmt.sampling_frequency();
        let channels = fmt.channel_num() as u16;
        let total_samples = fmt.sample_count();
        let block_size = fmt.block_size_per_channel();
        // DSF's `bits per sample` field is really a bit-order flag:
        // 1 = LSB-first (the common case), 8 = MSB-first.
        let bit_order = if fmt.bits_per_sample() == 8 {
            DsdBitOrder::MsbFirst
        } else {
            DsdBitOrder::LsbFirst
        };

        let mut file = dsf
            .file()
            .try_clone()
            .map_err(|e| anyhow!("Failed to clone DSF file handle: {}", e))?;
        drop(dsf);

        let data_offset = dsf_meta::DSF_SAMPLE_DATA_OFFSET;
        file.seek(SeekFrom::Start(data_offset))?;

        Ok(Self {
            file,
            sample_rate,
            channels,
            total_samples,
            data_offset,
            block_size,
            current_position: 0,
            bit_order,
            finished: false,
        })
    }

    pub fn block_size_per_channel(&self) -> u32 {
        self.block_size
    }
}

impl DsdFormatDecoder for DsfDecoder {
    fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    fn channels(&self) -> u16 {
        self.channels
    }

    fn total_samples(&self) -> u64 {
        self.total_samples
    }

    fn duration_secs(&self) -> f64 {
        if self.sample_rate == 0 {
            return 0.0;
        }
        self.total_samples as f64 / self.sample_rate as f64
    }

    fn seek(&mut self, sample: u64) -> Result<()> {
        let bytes_per_sample_block = self.block_size as u64 * self.channels as u64;
        let sample_block = sample / (self.block_size as u64 * 8);
        let target_byte = sample_block * bytes_per_sample_block;

        self.file
            .seek(SeekFrom::Start(self.data_offset + target_byte))?;
        self.current_position = sample;
        self.finished = false;
        Ok(())
    }

    fn read_dsd_bytes(&mut self, buf: &mut [u8]) -> Result<usize> {
        if self.finished {
            return Ok(0);
        }

        // FUSE-backed storage routinely returns short reads; keep reading so
        // the consumer always gets whole macro blocks (a truncated tail would
        // silently desync the per-channel blocks and tick audibly).
        let mut bytes_read = 0usize;
        while bytes_read < buf.len() {
            match self.file.read(&mut buf[bytes_read..]) {
                Ok(0) => break,
                Ok(n) => bytes_read += n,
                Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                Err(e) => return Err(e.into()),
            }
        }
        if bytes_read == 0 {
            self.finished = true;
        }

        let macro_block = self.block_size as u64 * self.channels as u64;
        let num_macro_blocks = bytes_read as u64 / macro_block;
        let samples_consumed = num_macro_blocks * self.block_size as u64 * 8;
        self.current_position += samples_consumed;

        if self.current_position >= self.total_samples {
            self.finished = true;
        }

        Ok(bytes_read)
    }

    fn is_finished(&self) -> bool {
        self.finished
    }

    fn channel_layout(&self) -> DsdChannelLayout {
        DsdChannelLayout::SequentialBlocks {
            block_size: self.block_size as usize,
        }
    }

    fn bit_order(&self) -> DsdBitOrder {
        self.bit_order
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn put_u32(buf: &mut [u8], off: usize, value: u32) {
        buf[off..off + 4].copy_from_slice(&value.to_le_bytes());
    }

    fn put_u64(buf: &mut [u8], off: usize, value: u64) {
        buf[off..off + 8].copy_from_slice(&value.to_le_bytes());
    }

    fn synthetic_dsf(bits_per_sample: u32, audio: &[u8]) -> Vec<u8> {
        let mut buf = vec![0u8; 92];
        buf[0..4].copy_from_slice(b"DSD ");
        put_u64(&mut buf, 4, 28);
        put_u64(&mut buf, 12, 92 + audio.len() as u64);
        put_u64(&mut buf, 20, 0);
        buf[28..32].copy_from_slice(b"fmt ");
        put_u64(&mut buf, 32, 52);
        put_u32(&mut buf, 40, 1);
        put_u32(&mut buf, 44, 0);
        put_u32(&mut buf, 48, 2);
        put_u32(&mut buf, 52, 2);
        put_u32(&mut buf, 56, 2_822_400);
        put_u32(&mut buf, 60, bits_per_sample);
        put_u64(&mut buf, 64, ((audio.len() / 2) * 8) as u64);
        put_u32(&mut buf, 72, 4096);
        put_u32(&mut buf, 76, 0);
        buf[80..84].copy_from_slice(b"data");
        put_u64(&mut buf, 84, 12 + audio.len() as u64);
        buf.extend_from_slice(audio);
        buf
    }

    fn write_temp(name: &str, bytes: &[u8]) -> std::path::PathBuf {
        let path = std::env::temp_dir().join(format!("flick_dsf_{}_{}.dsf", name, std::process::id()));
        std::fs::File::create(&path)
            .unwrap()
            .write_all(bytes)
            .unwrap();
        path
    }

    #[test]
    fn read_starts_at_spec_data_offset() {
        let audio: Vec<u8> = (0..8192).map(|i| (i * 7 + 3) as u8).collect();
        let path = write_temp("offset", &synthetic_dsf(1, &audio));

        let mut decoder = DsfDecoder::open(&path).unwrap();
        let mut out = vec![0u8; 8192];
        let read = decoder.read_dsd_bytes(&mut out).unwrap();
        let _ = std::fs::remove_file(&path);

        assert_eq!(read, 8192);
        assert_eq!(out, audio, "DSF sample data must start at byte 92");
    }

    #[test]
    fn bit_order_follows_header_flag() {
        let audio = vec![0u8; 8192];
        let lsb_path = write_temp("lsb", &synthetic_dsf(1, &audio));
        let msb_path = write_temp("msb", &synthetic_dsf(8, &audio));

        let lsb = DsfDecoder::open(&lsb_path).unwrap();
        let msb = DsfDecoder::open(&msb_path).unwrap();
        let _ = std::fs::remove_file(&lsb_path);
        let _ = std::fs::remove_file(&msb_path);

        assert_eq!(lsb.bit_order(), DsdBitOrder::LsbFirst);
        assert_eq!(msb.bit_order(), DsdBitOrder::MsbFirst);
    }
}
