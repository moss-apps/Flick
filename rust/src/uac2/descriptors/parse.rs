use super::audio_control_parser::AudioControlParser;
use super::audio_streaming_parser::AudioStreamingParser;
use super::iad_parser::parse_iad_internal;
use super::parser_trait::DescriptorParser;
use super::types::*;
use crate::uac2::error::Uac2Error;

const AC_PARSER: AudioControlParser = AudioControlParser;
const AS_PARSER: AudioStreamingParser = AudioStreamingParser;

#[derive(Clone)]
pub struct DescriptorIter<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> DescriptorIter<'a> {
    pub fn new(data: &'a [u8]) -> Self {
        Self { data, pos: 0 }
    }
}

impl<'a> Iterator for DescriptorIter<'a> {
    type Item = &'a [u8];

    fn next(&mut self) -> Option<Self::Item> {
        if self.pos >= self.data.len() || self.data.len() - self.pos < 2 {
            return None;
        }
        let len = self.data[self.pos] as usize;
        if len == 0 || self.pos + len > self.data.len() {
            return None;
        }
        let slice = &self.data[self.pos..self.pos + len];
        self.pos += len;
        Some(slice)
    }
}

// ── IAD ──
pub fn parse_iad(data: &[u8]) -> Result<Iad, Uac2Error> {
    parse_iad_internal(data)
}

// ── AC Header ──
pub fn parse_ac_interface_header(data: &[u8]) -> Result<AcInterfaceHeader, Uac2Error> {
    AC_PARSER.parse_ac_header(data)
}

pub fn parse_ac_interface_header_v1(data: &[u8]) -> Result<AcInterfaceHeaderV1, Uac2Error> {
    AC_PARSER.parse_ac_header_v1(data)
}

// ── Terminals ──
pub fn parse_input_terminal(data: &[u8]) -> Result<InputTerminal, Uac2Error> {
    AC_PARSER.parse_input_terminal(data)
}

pub fn parse_output_terminal(data: &[u8]) -> Result<OutputTerminal, Uac2Error> {
    AC_PARSER.parse_output_terminal(data)
}

// ── Feature Unit ──
pub fn parse_feature_unit(data: &[u8]) -> Result<FeatureUnit, Uac2Error> {
    AC_PARSER.parse_feature_unit(data)
}

// ── Clock entities ──
pub fn parse_clock_source(data: &[u8]) -> Result<ClockSource, Uac2Error> {
    AC_PARSER.parse_clock_source(data)
}

pub fn parse_clock_selector(data: &[u8]) -> Result<ClockSelector, Uac2Error> {
    AC_PARSER.parse_clock_selector(data)
}

pub fn parse_clock_multiplier(data: &[u8]) -> Result<ClockMultiplier, Uac2Error> {
    AC_PARSER.parse_clock_multiplier(data)
}

// ── Mixer / Selector / Effects ──
pub fn parse_mixer_unit(data: &[u8]) -> Result<MixerUnit, Uac2Error> {
    AC_PARSER.parse_mixer_unit(data)
}

pub fn parse_selector_unit(data: &[u8]) -> Result<SelectorUnit, Uac2Error> {
    AC_PARSER.parse_selector_unit(data)
}

pub fn parse_effect_unit(data: &[u8]) -> Result<EffectUnit, Uac2Error> {
    AC_PARSER.parse_effect_unit(data)
}

pub fn parse_processing_unit(data: &[u8]) -> Result<ProcessingUnit, Uac2Error> {
    AC_PARSER.parse_processing_unit(data)
}

pub fn parse_extension_unit(data: &[u8]) -> Result<ExtensionUnit, Uac2Error> {
    AC_PARSER.parse_extension_unit(data)
}

// ── AC Generic ──
pub fn parse_ac_descriptor(data: &[u8]) -> Result<AudioControlDescriptor, Uac2Error> {
    AC_PARSER.parse(data)
}

// ── AS ──
pub fn parse_as_interface_general(data: &[u8]) -> Result<AsInterfaceGeneral, Uac2Error> {
    AS_PARSER.parse_as_general_v2(data)
}

pub fn parse_as_general_descriptor(data: &[u8]) -> Result<AudioStreamingDescriptor, Uac2Error> {
    AS_PARSER.parse_as_general(data)
}

pub fn parse_format_type_i(data: &[u8]) -> Result<FormatTypeI, Uac2Error> {
    AS_PARSER.parse_format_type_i(data)
}

pub fn parse_format_type_ii(data: &[u8]) -> Result<FormatTypeII, Uac2Error> {
    AS_PARSER.parse_format_type_ii(data)
}

pub fn parse_format_type_iii(data: &[u8]) -> Result<FormatTypeIII, Uac2Error> {
    AS_PARSER.parse_format_type_iii(data)
}

pub fn parse_endpoint_specific(data: &[u8]) -> Result<EndpointSpecific, Uac2Error> {
    AS_PARSER.parse_endpoint_specific(data)
}

// ── AS Generic ──
pub fn parse_as_descriptor(data: &[u8]) -> Result<AudioStreamingDescriptor, Uac2Error> {
    AS_PARSER.parse(data)
}
