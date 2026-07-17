use std::env;
use std::path::PathBuf;

fn main() {
    let st_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("soundtouch");
    let source = st_root.join("source");

    let files = [
        "SoundTouch/AAFilter.cpp",
        "SoundTouch/BPMDetect.cpp",
        "SoundTouch/cpu_detect_x86.cpp",
        "SoundTouch/FIFOSampleBuffer.cpp",
        "SoundTouch/FIRFilter.cpp",
        "SoundTouch/InterpolateCubic.cpp",
        "SoundTouch/InterpolateLinear.cpp",
        "SoundTouch/InterpolateShannon.cpp",
        "SoundTouch/mmx_optimized.cpp",
        "SoundTouch/PeakFinder.cpp",
        "SoundTouch/RateTransposer.cpp",
        "SoundTouch/SoundTouch.cpp",
        "SoundTouch/sse_optimized.cpp",
        "SoundTouch/TDStretch.cpp",
        "SoundTouchDLL/SoundTouchDLL.cpp",
    ];

    let mut build = cc::Build::new();
    build
        .cpp(true)
        .warnings(false)
        .opt_level(2)
        .define("SOUNDTOUCH_FLOAT_SAMPLES", "1")
        .include(st_root.join("include"))
        .include(source.join("SoundTouch"))
        .include(source.join("SoundTouchDLL"));

    for file in files {
        build.file(source.join(file));
    }

    build.compile("soundtouch");

    println!("cargo:rerun-if-changed=soundtouch");
}
