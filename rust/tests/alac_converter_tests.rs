#[cfg(test)]
mod alac_converter_tests {
    use rust_lib_flick_player::audio::alac_converter::AudioMetadata;

    #[test]
    fn test_wav_header_generation() {
        let metadata = AudioMetadata {
            sample_rate: 44100,
            channels: 2,
            bit_depth: 16,
            duration_samples: 44100,
            duration_seconds: 1.0,
            is_float: false,
        };

        // Test that we can generate a valid WAV header
        // In a real test, you would load an actual ALAC file
        // For now, we just verify the struct can be created
        assert_eq!(metadata.sample_rate, 44100);
        assert_eq!(metadata.channels, 2);
        assert_eq!(metadata.bit_depth, 16);
    }

    #[test]
    fn test_metadata_calculations() {
        let metadata = AudioMetadata {
            sample_rate: 48000,
            channels: 2,
            bit_depth: 24,
            duration_samples: 48000 * 60, // 1 minute
            duration_seconds: 60.0,
            is_float: false,
        };

        assert_eq!(metadata.duration_seconds, 60.0);
        assert_eq!(metadata.duration_samples, 48000 * 60);
    }

    mod frame_reads {
        use rust_lib_flick_player::audio::alac_converter::ConversionSession;
        use std::io::Write;

        const SAMPLE_RATE: u32 = 44100;
        const CHANNELS: u16 = 2;
        const FRAMES: usize = 44100;

        fn expected_frame(frame: usize) -> [i16; 2] {
            let value = (frame % 1000) as i16;
            [value, -value]
        }

        fn expected_bytes(start: usize, count: usize) -> Vec<u8> {
            let mut out = Vec::with_capacity(count * 4);
            for frame in start..start + count {
                for sample in expected_frame(frame) {
                    out.extend_from_slice(&sample.to_le_bytes());
                }
            }
            out
        }

        fn write_wav(path: &std::path::Path) {
            let block_align = CHANNELS * 2;
            let data_size = (FRAMES * block_align as usize) as u32;
            let mut data = Vec::with_capacity(data_size as usize);
            for frame in 0..FRAMES {
                for sample in expected_frame(frame) {
                    data.extend_from_slice(&sample.to_le_bytes());
                }
            }

            let mut file = std::fs::File::create(path).unwrap();
            file.write_all(b"RIFF").unwrap();
            file.write_all(&(36 + data_size).to_le_bytes()).unwrap();
            file.write_all(b"WAVE").unwrap();
            file.write_all(b"fmt ").unwrap();
            file.write_all(&16u32.to_le_bytes()).unwrap();
            file.write_all(&1u16.to_le_bytes()).unwrap();
            file.write_all(&CHANNELS.to_le_bytes()).unwrap();
            file.write_all(&SAMPLE_RATE.to_le_bytes()).unwrap();
            file.write_all(&(SAMPLE_RATE * block_align as u32).to_le_bytes())
                .unwrap();
            file.write_all(&block_align.to_le_bytes()).unwrap();
            file.write_all(&16u16.to_le_bytes()).unwrap();
            file.write_all(b"data").unwrap();
            file.write_all(&data_size.to_le_bytes()).unwrap();
            file.write_all(&data).unwrap();
        }

        fn test_wav_path(name: &str) -> std::path::PathBuf {
            let dir = std::env::temp_dir().join("flick_alac_converter_tests");
            std::fs::create_dir_all(&dir).unwrap();
            let path = dir.join(name);
            write_wav(&path);
            path
        }

        #[test]
        fn session_from_path_reports_metadata() {
            let path = test_wav_path("metadata.wav");
            let session = ConversionSession::new_from_path(&path).unwrap();
            let metadata = session.metadata();
            assert_eq!(metadata.sample_rate, SAMPLE_RATE);
            assert_eq!(metadata.channels, CHANNELS);
            assert_eq!(metadata.bit_depth, 16);
            assert_eq!(metadata.duration_samples, FRAMES as u64);
            assert_eq!(session.block_align(), 4);
        }

        #[test]
        fn read_pcm_matches_source_frames() {
            let path = test_wav_path("sequential.wav");
            let mut session = ConversionSession::new_from_path(&path).unwrap();

            let head = session.read_pcm(0, 100).unwrap();
            assert_eq!(head, expected_bytes(0, 100));
            assert_eq!(session.current_frame(), 100);

            let middle = session.read_pcm(100, 50).unwrap();
            assert_eq!(middle, expected_bytes(100, 50));
            assert_eq!(session.current_frame(), 150);
        }

        #[test]
        fn partial_reads_stay_gapless() {
            let path = test_wav_path("partial.wav");
            let mut session = ConversionSession::new_from_path(&path).unwrap();

            let first = session.read_pcm(0, 3).unwrap();
            let second = session.read_pcm(3, 3).unwrap();
            let mut joined = first;
            joined.extend_from_slice(&second);
            assert_eq!(joined, expected_bytes(0, 6));
        }

        #[test]
        fn seek_frame_is_exact_and_reads_forward() {
            let path = test_wav_path("seek.wav");
            let mut session = ConversionSession::new_from_path(&path).unwrap();

            assert_eq!(session.seek_frame(1000).unwrap(), 1000);
            assert_eq!(session.read_pcm(1000, 10).unwrap(), expected_bytes(1000, 10));

            // Later position without a seek keeps decoding forward.
            assert_eq!(session.read_pcm(5000, 4).unwrap(), expected_bytes(5000, 4));

            // Backwards seek repositions exactly.
            assert_eq!(session.seek_frame(1234).unwrap(), 1234);
            assert_eq!(session.read_pcm(1234, 5).unwrap(), expected_bytes(1234, 5));
        }

        #[test]
        fn read_pcm_returns_short_at_end_of_stream() {
            let path = test_wav_path("eof.wav");
            let mut session = ConversionSession::new_from_path(&path).unwrap();

            let tail = session.read_pcm((FRAMES - 10) as u64, 100).unwrap();
            assert_eq!(tail, expected_bytes(FRAMES - 10, 10));

            let after_end = session.read_pcm(FRAMES as u64, 10).unwrap();
            assert!(after_end.is_empty());
        }

        #[test]
        fn session_from_path_rejects_non_audio() {
            let dir = std::env::temp_dir().join("flick_alac_converter_tests");
            std::fs::create_dir_all(&dir).unwrap();
            let path = dir.join("not_audio.bin");
            std::fs::write(&path, b"definitely not audio").unwrap();
            assert!(ConversionSession::new_from_path(&path).is_err());
        }
    }
}
