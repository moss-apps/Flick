pub const USB_DT_INTERFACE_ASSOCIATION: u8 = 0x0b;
pub const USB_DT_CS_INTERFACE: u8 = 0x24;
pub const USB_DT_CS_ENDPOINT: u8 = 0x25;

// ── UAC 1.0 / 2.0 AC descriptor subtypes ──
pub const UAC_AC_HEADER: u8 = 0x01;
pub const UAC_INPUT_TERMINAL: u8 = 0x02;
pub const UAC_OUTPUT_TERMINAL: u8 = 0x03;
pub const UAC_MIXER_UNIT: u8 = 0x04;
pub const UAC_SELECTOR_UNIT: u8 = 0x05;
pub const UAC_FEATURE_UNIT: u8 = 0x06;
pub const UAC_EFFECT_UNIT: u8 = 0x07;
pub const UAC_PROCESSING_UNIT: u8 = 0x08;
pub const UAC_EXTENSION_UNIT: u8 = 0x09;

// ── UAC 2.0+ AC additional subtypes ──
pub const UAC2_CLOCK_SOURCE: u8 = 0x0a;
pub const UAC2_CLOCK_SELECTOR: u8 = 0x0b;
pub const UAC2_CLOCK_MULTIPLIER: u8 = 0x0c;

// ── UAC AS descriptor subtypes ──
pub const UAC_AS_GENERAL: u8 = 0x01;
pub const UAC_FORMAT_TYPE: u8 = 0x02;

// ── Alias for backward-compat ──
pub const UAC2_AC_HEADER: u8 = 0x01;
pub const UAC2_INPUT_TERMINAL: u8 = 0x02;
pub const UAC2_OUTPUT_TERMINAL: u8 = 0x03;
pub const UAC2_FEATURE_UNIT: u8 = 0x06;
pub const UAC2_AS_GENERAL: u8 = 0x01;
pub const UAC2_FORMAT_TYPE: u8 = 0x02;

// ── UAC format type IDs ──
pub const UAC2_FORMAT_TYPE_I: u8 = 0x01;
pub const UAC2_FORMAT_TYPE_II: u8 = 0x02;
pub const UAC2_FORMAT_TYPE_III: u8 = 0x03;

pub const UAC2_BCD_ADC: u16 = 0x0200;
pub const UAC1_BCD_ADC: u16 = 0x0100;

// ── Terminal types ──
pub const TERMINAL_TYPE_USB_STREAMING: u16 = 0x0101;
pub const TERMINAL_TYPE_OUTPUT_SPEAKER: u16 = 0x0301;
pub const TERMINAL_TYPE_OUTPUT_HEADPHONES: u16 = 0x0302;
pub const TERMINAL_TYPE_INPUT_MICROPHONE: u16 = 0x0201;
pub const TERMINAL_TYPE_INPUT_LINE: u16 = 0x0202;

// ── Feature unit control bits ──
pub const FEATURE_MUTE: u32 = 0x0001;
pub const FEATURE_VOLUME: u32 = 0x0002;
pub const FEATURE_BASS: u32 = 0x0004;
pub const FEATURE_MID: u32 = 0x0008;
pub const FEATURE_TREBLE: u32 = 0x0010;
pub const FEATURE_GRAPHIC_EQ: u32 = 0x0020;
pub const FEATURE_AGC: u32 = 0x0040;
pub const FEATURE_DELAY: u32 = 0x0080;
pub const FEATURE_BASS_BOOST: u32 = 0x0100;
pub const FEATURE_LOUDNESS: u32 = 0x0200;

// ── Clock source attribute flags ──
pub const CLOCK_SOURCE_TYPE_MASK: u8 = 0x03;
pub const CLOCK_SOURCE_TYPE_EXTERNAL: u8 = 0x00;
pub const CLOCK_SOURCE_TYPE_INTERNAL_FIXED: u8 = 0x01;
pub const CLOCK_SOURCE_TYPE_INTERNAL_VARIABLE: u8 = 0x02;
pub const CLOCK_SOURCE_TYPE_INTERNAL_PROGRAMMABLE: u8 = 0x03;
pub const CLOCK_SOURCE_SYNC_TO_SOF: u8 = 0x04;

// ── Clock source control flags ──
pub const CLOCK_CONTROL_FREQUENCY_GET: u8 = 0x01;
pub const CLOCK_CONTROL_FREQUENCY_SET: u8 = 0x02;
pub const CLOCK_CONTROL_CLOCK_VALID: u8 = 0x04;

// ── UAC request codes ──
pub const UAC2_REQUEST_SET_CUR: u8 = 0x01;
pub const UAC2_REQUEST_GET_CUR: u8 = 0x81;
pub const UAC2_REQUEST_GET_MIN: u8 = 0x82;
pub const UAC2_REQUEST_GET_MAX: u8 = 0x83;
pub const UAC2_REQUEST_GET_RES: u8 = 0x84;
pub const UAC2_REQUEST_GET_RANGE: u8 = 0x82;

// ── Clock control selectors ──
pub const UAC2_CLOCK_SOURCE_SAM_FREQ_CONTROL: u16 = 0x0100;
pub const UAC2_CLOCK_SOURCE_CLOCK_VALID_CONTROL: u16 = 0x0200;

// ── USB bmRequestType components ──
pub const USB_DIR_OUT: u8 = 0x00;
pub const USB_DIR_IN: u8 = 0x80;
pub const USB_TYPE_CLASS: u8 = 0x20;
pub const USB_RECIP_INTERFACE: u8 = 0x01;

// ── USB class codes ──
pub const USB_CLASS_AUDIO: u8 = 0x01;
pub const USB_SUBCLASS_AUDIOCONTROL: u8 = 0x01;
pub const USB_SUBCLASS_AUDIOSTREAMING: u8 = 0x02;

// ── Format tags ──
pub const FORMAT_TAG_PCM: u16 = 0x0001;
pub const FORMAT_TAG_PCM8: u16 = 0x0002;
pub const FORMAT_TAG_IEEE_FLOAT: u16 = 0x0003;
pub const FORMAT_TAG_DSD: u16 = 0x0008;
pub const FORMAT_TAG_MPEG: u16 = 0x0050;
pub const FORMAT_TAG_AC3: u16 = 0x0092;

// ── Feature unit control selectors ──
pub const UAC2_FEATURE_UNIT_MUTE_CONTROL: u16 = 0x0101;
pub const UAC2_FEATURE_UNIT_VOLUME_CONTROL: u16 = 0x0100;

// ── Endpoint-specific descriptor attribute flags ──
pub const EP_SPECIFIC_MAX_PACKETS_ONLY: u8 = 0x80;
pub const EP_SPECIFIC_PITCH_CONTROL: u8 = 0x40;
pub const EP_SPECIFIC_DATA_OVERRUN: u8 = 0x20;
pub const EP_SPECIFIC_DATA_UNDERRUN: u8 = 0x10;
