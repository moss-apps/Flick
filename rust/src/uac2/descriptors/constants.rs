pub const USB_DT_INTERFACE_ASSOCIATION: u8 = 0x0B;
pub const USB_DT_CS_INTERFACE: u8 = 0x24;
pub const USB_DT_CS_ENDPOINT: u8 = 0x25;

pub const UAC_AC_HEADER: u8 = 0x01;
pub const UAC_INPUT_TERMINAL: u8 = 0x02;
pub const UAC_OUTPUT_TERMINAL: u8 = 0x03;
pub const UAC_MIXER_UNIT: u8 = 0x04;
pub const UAC_SELECTOR_UNIT: u8 = 0x05;
pub const UAC_FEATURE_UNIT: u8 = 0x06;
pub const UAC_EFFECT_UNIT: u8 = 0x07;
pub const UAC_PROCESSING_UNIT: u8 = 0x08;
pub const UAC_EXTENSION_UNIT: u8 = 0x09;

pub const UAC2_CLOCK_SOURCE: u8 = 0x0a;
pub const UAC2_CLOCK_SELECTOR: u8 = 0x0b;
pub const UAC2_CLOCK_MULTIPLIER: u8 = 0x0c;

// Backward-compat aliases
pub const UAC2_AC_HEADER: u8 = UAC_AC_HEADER;
pub const UAC2_INPUT_TERMINAL: u8 = UAC_INPUT_TERMINAL;
pub const UAC2_OUTPUT_TERMINAL: u8 = UAC_OUTPUT_TERMINAL;
pub const UAC2_FEATURE_UNIT: u8 = UAC_FEATURE_UNIT;

pub const UAC2_AS_GENERAL: u8 = 0x01;
pub const UAC2_FORMAT_TYPE: u8 = 0x02;

pub const UAC2_FORMAT_TYPE_I: u8 = 0x01;
pub const UAC2_FORMAT_TYPE_II: u8 = 0x02;
pub const UAC2_FORMAT_TYPE_III: u8 = 0x03;

pub const UAC2_BCD_ADC: u16 = 0x0200;
pub const UAC1_BCD_ADC: u16 = 0x0100;
