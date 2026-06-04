#[derive(Debug, Clone)]
pub struct Iad {
    pub b_first_interface: u8,
    pub b_interface_count: u8,
    pub b_function_class: u8,
    pub b_function_sub_class: u8,
    pub b_function_protocol: u8,
    pub i_function: u8,
}

// ── UAC 1.0 AC Interface Header ──
#[derive(Debug, Clone)]
pub struct AcInterfaceHeaderV1 {
    pub bcd_adc: u16,
    pub w_total_length: u16,
    pub b_in_collection: u8,
    pub ba_interface_nr: Vec<u8>,
}

// ── UAC 2.0 AC Interface Header ──
#[derive(Debug, Clone)]
pub struct AcInterfaceHeaderV2 {
    pub bcd_adc: u16,
    pub b_category: u8,
    pub w_total_length: u16,
    pub bm_controls: u16,
}

// ── Backward-compat alias ──
pub type AcInterfaceHeader = AcInterfaceHeaderV2;

#[derive(Debug, Clone)]
pub struct InputTerminal {
    pub b_terminal_id: u8,
    pub w_terminal_type: u16,
    pub b_assoc_terminal: u8,
    pub b_c_source_id: u8,
    pub b_nr_channels: u16,
    pub w_channel_config: u32,
    pub i_terminal: u8,
}

#[derive(Debug, Clone)]
pub struct OutputTerminal {
    pub b_terminal_id: u8,
    pub w_terminal_type: u16,
    pub b_assoc_terminal: u8,
    pub b_source_id: u8,
    pub i_terminal: u8,
}

#[derive(Debug, Clone)]
pub struct FeatureUnit {
    pub b_unit_id: u8,
    pub b_source_id: u8,
    pub b_control_size: u8,
    pub bma_controls: Vec<u32>,
}

// ── Clock Source (UAC 2.0 / UAC 3.0) ──
#[derive(Debug, Clone)]
pub struct ClockSource {
    pub b_clock_id: u8,
    pub bm_attributes: u8,
    pub bm_controls: u8,
    pub b_assoc_terminal: u8,
    pub i_clock_source: u8,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ClockType {
    External,
    InternalFixed,
    InternalVariable,
    InternalProgrammable,
}

impl ClockSource {
    pub fn clock_type(&self) -> ClockType {
        match self.bm_attributes & 0x03 {
            0 => ClockType::External,
            1 => ClockType::InternalFixed,
            2 => ClockType::InternalVariable,
            3 => ClockType::InternalProgrammable,
            _ => ClockType::External,
        }
    }

    pub fn is_synchronous_to_sof(&self) -> bool {
        (self.bm_attributes & 0x04) != 0
    }

    pub fn supports_frequency_get(&self) -> bool {
        (self.bm_controls & 0x01) != 0
    }

    pub fn supports_frequency_set(&self) -> bool {
        (self.bm_controls & 0x02) != 0
    }

    pub fn supports_clock_valid(&self) -> bool {
        (self.bm_controls & 0x04) != 0
    }
}

// ── Clock Selector (UAC 2.0) ──
#[derive(Debug, Clone)]
pub struct ClockSelector {
    pub b_clock_id: u8,
    pub b_nr_in_pins: u8,
    pub ba_c_source_id: Vec<u8>,
    pub bm_controls: u8,
    pub i_clock_selector: u8,
}

// ── Clock Multiplier (UAC 2.0) ──
#[derive(Debug, Clone)]
pub struct ClockMultiplier {
    pub b_clock_id: u8,
    pub b_c_source_id: u8,
    pub bm_controls: u8,
    pub i_clock_multiplier: u8,
}

// ── Mixer Unit ──
#[derive(Debug, Clone)]
pub struct MixerUnit {
    pub b_unit_id: u8,
    pub b_nr_in_pins: u8,
    pub ba_source_id: Vec<u8>,
    pub b_nr_channels: u16,
    pub w_channel_config: u32,
    pub i_mixer: u8,
    pub bm_controls: Vec<u8>,
}

// ── Selector Unit ──
#[derive(Debug, Clone)]
pub struct SelectorUnit {
    pub b_unit_id: u8,
    pub b_nr_in_pins: u8,
    pub ba_source_id: Vec<u8>,
    pub i_selector: u8,
    pub bm_controls: Option<u8>,
}

// ── Effect Unit ──
#[derive(Debug, Clone)]
pub struct EffectUnit {
    pub b_unit_id: u8,
    pub b_source_id: u8,
    pub b_effect_id: u16,
    pub i_effect: u8,
}

// ── Processing Unit ──
#[derive(Debug, Clone)]
pub struct ProcessingUnit {
    pub b_unit_id: u8,
    pub b_source_id: u8,
    pub w_process_type: u16,
    pub b_nr_channels: u16,
    pub w_channel_config: u32,
    pub i_processing: u8,
    pub bm_controls: Vec<u8>,
}

// ── Extension Unit ──
#[derive(Debug, Clone)]
pub struct ExtensionUnit {
    pub b_unit_id: u8,
    pub w_extension_code: u16,
    pub b_nr_in_pins: u8,
    pub ba_source_id: Vec<u8>,
    pub b_nr_channels: u16,
    pub w_channel_config: u32,
    pub i_extension: u8,
    pub bm_controls: Vec<u8>,
}

// ── UAC 1.0 AS General ──
#[derive(Debug, Clone)]
pub struct AsInterfaceGeneralV1 {
    pub b_terminal_link: u8,
    pub b_delay: u8,
    pub w_format_tag: u16,
}

// ── UAC 2.0 AS General ──
#[derive(Debug, Clone)]
pub struct AsInterfaceGeneralV2 {
    pub b_terminal_link: u8,
    pub b_delay: u8,
    pub bm_controls: u16,
    pub w_format_tag: u16,
}

pub type AsInterfaceGeneral = AsInterfaceGeneralV2;

#[derive(Debug, Clone)]
pub struct FormatTypeI {
    pub b_subslot_size: u8,
    pub b_bit_resolution: u8,
    pub b_sam_freq_type: u8,
    pub sample_rates: Vec<u32>,
}

#[derive(Debug, Clone)]
pub struct FormatTypeII {
    pub w_max_bit_rate: u16,
    pub w_samples_per_frame: u16,
    pub b_sam_freq_type: u8,
    pub sample_rates: Vec<u32>,
}

#[derive(Debug, Clone)]
pub struct FormatTypeIII {
    pub b_subslot_size: u8,
    pub b_bit_resolution: u8,
}

// ── Endpoint-Specific Descriptor (CS_ENDPOINT) ──
#[derive(Debug, Clone)]
pub struct EndpointSpecific {
    pub b_endpoint_address: u8,
    pub bm_attributes: u8,
    pub b_lock_delay_units: u8,
    pub w_lock_delay: u16,
}

impl EndpointSpecific {
    pub fn max_packets_only(&self) -> bool {
        (self.bm_attributes & 0x80) != 0
    }

    pub fn pitch_control(&self) -> bool {
        (self.bm_attributes & 0x40) != 0
    }

    pub fn data_overrun_control(&self) -> bool {
        (self.bm_attributes & 0x20) != 0
    }

    pub fn data_underrun_control(&self) -> bool {
        (self.bm_attributes & 0x10) != 0
    }
}

// ── Unified Descriptor Enums ──

#[derive(Debug, Clone)]
pub enum AudioControlDescriptor {
    HeaderV1(AcInterfaceHeaderV1),
    HeaderV2(AcInterfaceHeaderV2),
    InputTerminal(InputTerminal),
    OutputTerminal(OutputTerminal),
    FeatureUnit(FeatureUnit),
    ClockSource(ClockSource),
    ClockSelector(ClockSelector),
    ClockMultiplier(ClockMultiplier),
    MixerUnit(MixerUnit),
    SelectorUnit(SelectorUnit),
    EffectUnit(EffectUnit),
    ProcessingUnit(ProcessingUnit),
    ExtensionUnit(ExtensionUnit),
}

#[derive(Debug, Clone)]
pub enum AudioStreamingDescriptor {
    GeneralV1(AsInterfaceGeneralV1),
    GeneralV2(AsInterfaceGeneralV2),
    FormatTypeI(FormatTypeI),
    FormatTypeII(FormatTypeII),
    FormatTypeIII(FormatTypeIII),
    EndpointSpecific(EndpointSpecific),
}

#[derive(Debug, Clone)]
pub enum DescriptorKind {
    Iad(Iad),
    AudioControl(AudioControlDescriptor),
    AudioStreaming(AudioStreamingDescriptor),
}
