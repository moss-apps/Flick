use rust_lib_flick_player::audio::alac_converter::ConversionSession;
use std::fs;
use std::path::{Path, PathBuf};

// Real-codec coverage for path sessions and ranged reads. Fixtures are not
// committed; generate them with ffmpeg and point FLICK_REAL_CODEC_DIR at the
// directory:
//
//   ffmpeg -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=5" \
//     -ac 2 -c:a alac alac.m4a
//   ffmpeg -f lavfi -i "sine=frequency=330:sample_rate=48000:duration=3" \
//     -ac 2 -c:a pcm_s16be aiff.aiff
//   ffmpeg -i alac.m4a -f s32le -acodec pcm_s32le alac.pcm
//   ffmpeg -i aiff.aiff -f s16le -acodec pcm_s16le aiff.pcm
//
// Without the env var the test is a no-op.
fn fixture_dir() -> Option<PathBuf> {
    let dir = PathBuf::from(std::env::var_os("FLICK_REAL_CODEC_DIR")?);
    dir.is_dir().then_some(dir)
}

fn check(name: &str, encoded: &Path, reference: &Path) {
    let ref_bytes = fs::read(reference).unwrap();
    let mut session = ConversionSession::new_from_path(encoded).unwrap();
    let meta = session.metadata().clone();
    let align = meta.channels as usize * (meta.bit_depth / 8) as usize;
    assert!(align > 0, "{name}: bad layout");
    assert_eq!(
        ref_bytes.len() % align,
        0,
        "{name}: reference not frame aligned"
    );
    let frames = (ref_bytes.len() / align) as u64;
    assert!(
        meta.duration_samples >= frames,
        "{name}: duration_samples {} < decoded frames {frames}",
        meta.duration_samples
    );

    let full = session.read_pcm(0, meta.duration_samples).unwrap();
    assert_eq!(full, ref_bytes, "{name}: full decode mismatch");

    let mid = frames / 2;
    let tail = session.read_pcm(mid, frames - mid).unwrap();
    assert_eq!(
        tail,
        &ref_bytes[mid as usize * align..],
        "{name}: seek-to-middle mismatch"
    );

    let head = session.read_pcm(100, 500).unwrap();
    assert_eq!(
        head,
        &ref_bytes[100 * align..600 * align],
        "{name}: backwards seek mismatch"
    );

    let short = session.read_pcm(frames - 10, 10).unwrap();
    assert_eq!(
        short,
        &ref_bytes[(frames as usize - 10) * align..],
        "{name}: tail seek mismatch"
    );

    let past_end = session.read_pcm(meta.duration_samples + 5, 10).unwrap();
    assert!(past_end.is_empty(), "{name}: past-eof should be empty");
}

#[test]
fn real_codec_files() {
    let Some(dir) = fixture_dir() else {
        eprintln!("FLICK_REAL_CODEC_DIR not set, skipping");
        return;
    };
    check(
        "alac-m4a",
        &dir.join("alac.m4a"),
        &dir.join("alac.pcm"),
    );
    check("aiff", &dir.join("aiff.aiff"), &dir.join("aiff.pcm"));
}
