use super::{DsdChannelLayout, DsdFormatDecoder};
use anyhow::{anyhow, Result};
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;

const DSF_SAMPLE_DATA_OFFSET: u64 = 92;

pub struct DsfDecoder {
    file: File,
    sample_rate: u32,
    channels: u16,
    total_samples: u64,
    data_offset: u64,
    data_size: u64,
    block_size: u32,
    current_position: u64,
    finished: bool,
}

impl DsfDecoder {
    pub fn open(path: &Path) -> Result<Self> {
        let mut file = File::open(path).map_err(|e| anyhow!("Failed to open DSF: {}", e))?;

        let dsf = dsf_meta::DsfFile::open(path)
            .map_err(|e| anyhow!("Failed to parse DSF header: {}", e))?;

        let fmt = dsf.fmt_chunk();
        let sample_rate = fmt.sampling_frequency();
        let channels = fmt.channel_num() as u16;
        let total_samples = fmt.sample_count();
        let block_size = fmt.block_size_per_channel();

        let data = dsf.data_chunk();
        let data_size = data.chunk_size().saturating_sub(12);

        drop(dsf);

        file.seek(SeekFrom::Start(DSF_SAMPLE_DATA_OFFSET))?;

        Ok(Self {
            file,
            sample_rate,
            channels,
            total_samples,
            data_offset: DSF_SAMPLE_DATA_OFFSET,
            data_size,
            block_size,
            current_position: 0,
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
        let sample_block = sample / self.block_size as u64;
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

        let bytes_read = self.file.read(buf)?;
        if bytes_read == 0 {
            self.finished = true;
        }

        let samples_consumed = (bytes_read as u64 / self.channels as u64) * 8;
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
}
