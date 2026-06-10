use std::sync::Mutex;

use symphonia::core::audio::{AudioBuffer, AudioBufferRef, Signal, SignalSpec};
use symphonia::core::codecs::{
    CodecDescriptor, CodecParameters, Decoder, DecoderOptions, FinalizeResult, CODEC_TYPE_OPUS,
};
use symphonia::core::errors::{decode_error, Error, Result, unsupported_error};
use symphonia::core::formats::Packet;
use symphonia::core::units::TimeBase;

pub struct OpusDecoder {
    inner: Mutex<opus_sys::Decoder>,
    params: CodecParameters,
    buf: Vec<f32>,
    decoded: AudioBuffer<f32>,
}

impl Decoder for OpusDecoder {
    fn try_new(params: &CodecParameters, _options: &DecoderOptions) -> Result<Self> {
        let channels = params.channels.map(|c| c.count()).unwrap_or(2);
        let sample_rate = params.sample_rate.unwrap_or(48_000);

        let ch = match channels {
            1 => opus_sys::Channels::Mono,
            2 => opus_sys::Channels::Stereo,
            _ => return unsupported_error("opus: only mono and stereo are supported"),
        };

        let inner = opus_sys::Decoder::new(sample_rate, ch)
            .or_else(|e| Err(Error::IoError(std::io::Error::new(
                std::io::ErrorKind::Other,
                format!("opus decoder init: error code {}", e),
            ))))?;

        let mut codec_params = CodecParameters::new();
        codec_params
            .for_codec(CODEC_TYPE_OPUS)
            .with_sample_rate(sample_rate)
            .with_time_base(TimeBase::new(1, sample_rate))
            .with_channels(params.channels.unwrap_or(
                symphonia::core::audio::Channels::FRONT_LEFT
                    | symphonia::core::audio::Channels::FRONT_RIGHT,
            ));

        if let Some(delay) = params.delay {
            codec_params.with_delay(delay);
        }

        Ok(OpusDecoder {
            inner: Mutex::new(inner),
            params: codec_params,
            buf: Vec::new(),
            decoded: AudioBuffer::unused(),
        })
    }

    fn supported_codecs() -> &'static [CodecDescriptor] {
        static DESCRIPTORS: &[CodecDescriptor] = &[CodecDescriptor {
            codec: CODEC_TYPE_OPUS,
            short_name: "opus",
            long_name: "Opus (via libopus)",
            inst_func: |params, opts| {
                OpusDecoder::try_new(params, opts)
                    .map(|d| Box::new(d) as Box<dyn Decoder>)
            },
        }];
        DESCRIPTORS
    }

    fn decode(&mut self, packet: &Packet) -> Result<AudioBufferRef<'_>> {
        let channels = self
            .params
            .channels
            .map(|c| c.count())
            .unwrap_or(2)
            .max(1);
        let data = &packet.data;

        if data.is_empty() {
            let frames = channels * 960;
            self.buf.resize(frames, 0.0f32);
            if let Ok(inner) = self.inner.get_mut() {
                let _ = inner.decode_float(&[], &mut self.buf, true);
            }
        } else if let Ok(inner) = self.inner.get_mut() {
            let nb_samples = inner
                .get_nb_samples(data)
                .or_else(|_| decode_error("opus: failed to get sample count"))?;
            let total = nb_samples * channels;
            self.buf.resize(total, 0.0f32);
            inner
                .decode_float(data, &mut self.buf, false)
                .or_else(|_| decode_error("opus: decode failed"))?;
        } else {
            return decode_error("opus: mutex poisoned");
        }

        let n_frames = self.buf.len() / channels;
        let rate = self.params.sample_rate.unwrap_or(48_000);
        let spec_channels = self
            .params
            .channels
            .unwrap_or(symphonia::core::audio::Channels::FRONT_LEFT
                | symphonia::core::audio::Channels::FRONT_RIGHT);
        let spec = SignalSpec::new(rate, spec_channels);

        self.decoded = AudioBuffer::<f32>::new(n_frames as u64, spec);

        self.decoded.render(Some(n_frames), |planes, _frame_count| {
            for (ch, plane) in planes.planes().iter_mut().enumerate() {
                for f in 0..n_frames {
                    plane[f] = self.buf[f * channels + ch];
                }
            }
            Ok(())
        })?;

        Ok(AudioBufferRef::F32(std::borrow::Cow::Borrowed(
            &self.decoded,
        )))
    }

    fn reset(&mut self) {
        if let Ok(inner) = self.inner.get_mut() {
            let _ = inner.reset_state();
        }
    }

    fn codec_params(&self) -> &CodecParameters {
        &self.params
    }

    fn finalize(&mut self) -> FinalizeResult {
        FinalizeResult { verify_ok: None }
    }

    fn last_decoded(&self) -> AudioBufferRef<'_> {
        AudioBufferRef::F32(std::borrow::Cow::Borrowed(&self.decoded))
    }
}
