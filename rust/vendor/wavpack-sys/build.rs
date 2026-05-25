use std::env;
use std::path::PathBuf;

fn main() {
    let wavpack_src = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("wavpack/src");
    let wavpack_include =
        PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("wavpack/include");

    let decode_sources = [
        "common_utils.c",
        "decorr_utils.c",
        "entropy_utils.c",
        "open_filename.c",
        "open_legacy.c",
        "open_raw.c",
        "open_utils.c",
        "read_words.c",
        "tags.c",
        "tag_utils.c",
        "unpack.c",
        "unpack_dsd.c",
        "unpack_floats.c",
        "unpack_seek.c",
        "unpack_utils.c",
        "unpack3.c",
        "unpack3_open.c",
        "unpack3_seek.c",
        "write_words.c",
    ];

    let mut build = cc::Build::new();
    build
        .warnings(false)
        .opt_level(2)
        .define("WAVPACK_ENABLE_LEGACY", None)
        .define("ENABLE_DSD", None)
        .include(&wavpack_src)
        .include(&wavpack_include);

    for src in &decode_sources {
        build.file(wavpack_src.join(src));
    }

    build.compile("wavpack");

    let bindings = bindgen::Builder::default()
        .header(
            wavpack_include
                .join("wavpack.h")
                .to_str()
                .unwrap(),
        )
        .clang_arg(format!("-I{}", wavpack_include.display()))
        .clang_arg(format!("-I{}", wavpack_src.display()))
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .allowlist_function("Wavpack.*")
        .allowlist_type("Wavpack.*")
        .allowlist_var("(OPEN_|MODE_|CONFIG_|QMODE_|BYTES_STORED|MONO_FLAG|HYBRID_FLAG|JOINT_STEREO|CROSS_DECORR|HYBRID_SHAPE|FLOAT_DATA|INT32_DATA|HYBRID_BITRATE|HYBRID_BALANCE|INITIAL_BLOCK|FINAL_BLOCK|SHIFT_LSB|SHIFT_MASK|MAG_LSB|MAG_MASK|SRATE_LSB|SRATE_MASK|FALSE_STEREO|NEW_SHAPING|HAS_CHECKSUM|DSD_FLAG|WP_FORMAT_.*|MAX_WAVPACK_SAMPLES).*")
        .no_copy("WavpackContext")
        .size_t_is_usize(true)
        .generate()
        .expect("Unable to generate wavpack bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings");
}
