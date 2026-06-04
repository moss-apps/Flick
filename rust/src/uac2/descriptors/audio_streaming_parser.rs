use super::constants::*;
use super::helpers::{read_u16_le, read_u32_le, require_len};
use super::parser_trait::DescriptorParser;
use super::types::*;
use super::validation::{
    validate_as_interface_general, validate_format_type_i, validate_format_type_ii,
    validate_format_type_iii,
};
use crate::uac2::error::Uac2Error;

pub struct AudioStreamingParser;

impl AudioStreamingParser {
    pub fn parse_as_general(&self, data: &[u8]) -> Result<AudioStreamingDescriptor, Uac2Error> {
        if data.len() < 7 {
            return Err(Uac2Error::InvalidDescriptor("AS general too short".to_string()));
        }
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_AS_GENERAL {
            return Err(Uac2Error::InvalidDescriptor("not AS general".to_string()));
        }
        // UAC 2.0 AS General has bmControls at offset 5-6; UAC 1.0 doesn't
        // Distinguishing heuristic: UAC 2.0 has bTerminalLink(3), bDelay(4),
        // bmControls(5-6), wFormatTag(7-8). UAC 1.0: bTerminalLink(3),
        // bDelay(4), wFormatTag(5-6).
        let len = data[0] as usize;
        if len >= 9 {
            // UAC 2.0 style
            let g = AsInterfaceGeneralV2 {
                b_terminal_link: data[3],
                b_delay: data[4],
                bm_controls: read_u16_le(data, 5),
                w_format_tag: read_u16_le(data, 7),
            };
            validate_as_interface_general(&AsInterfaceGeneral {
                b_terminal_link: g.b_terminal_link,
                b_delay: g.b_delay,
                w_format_tag: g.w_format_tag,
                bm_controls: g.bm_controls,
            })?;
            Ok(AudioStreamingDescriptor::GeneralV2(g))
        } else {
            // UAC 1.0 style
            let g = AsInterfaceGeneralV1 {
                b_terminal_link: data[3],
                b_delay: data[4],
                w_format_tag: read_u16_le(data, 5),
            };
            Ok(AudioStreamingDescriptor::GeneralV1(g))
        }
    }

    /// Backward-compat: returns the V2 form (or V1 adapted)
    pub fn parse_as_general_v2(&self, data: &[u8]) -> Result<AsInterfaceGeneral, Uac2Error> {
        const LEN: usize = 7;
        require_len(data, LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_AS_GENERAL {
            return Err(Uac2Error::InvalidDescriptor("not AS general".to_string()));
        }
        let len = data[0] as usize;
        let (b_terminal_link, b_delay, w_format_tag, bm_controls) = if len >= 9 {
            (
                data[3],
                data[4],
                read_u16_le(data, 7),
                read_u16_le(data, 5),
            )
        } else {
            (data[3], data[4], read_u16_le(data, 5), 0u16)
        };
        let g = AsInterfaceGeneral {
            b_terminal_link,
            b_delay,
            w_format_tag,
            bm_controls,
        };
        validate_as_interface_general(&g)?;
        Ok(g)
    }

    pub fn parse_format_type_i(&self, data: &[u8]) -> Result<FormatTypeI, Uac2Error> {
        const MIN_LEN: usize = 8;
        require_len(data, MIN_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE
            || data[2] != UAC2_FORMAT_TYPE
            || data[3] != UAC2_FORMAT_TYPE_I
        {
            return Err(Uac2Error::InvalidDescriptor(
                "not format type I".to_string(),
            ));
        }
        let b_sam_freq_type = data[6];
        let mut sample_rates: Vec<u32> = Vec::new();
        if b_sam_freq_type == 0 {
            if data.len() >= 10 {
                sample_rates.push(read_u32_le(data, 7));
            }
        } else {
            let num_rates = b_sam_freq_type as usize;
            require_len(data, 7 + num_rates * 6)?;
            for i in 0..num_rates {
                sample_rates.push(read_u32_le(data, 7 + i * 6));
            }
        }
        let f = FormatTypeI {
            b_subslot_size: data[4],
            b_bit_resolution: data[5],
            b_sam_freq_type,
            sample_rates,
        };
        validate_format_type_i(&f)?;
        Ok(f)
    }

    pub fn parse_format_type_ii(&self, data: &[u8]) -> Result<FormatTypeII, Uac2Error> {
        const MIN_LEN: usize = 10;
        require_len(data, MIN_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE
            || data[2] != UAC2_FORMAT_TYPE
            || data[3] != UAC2_FORMAT_TYPE_II
        {
            return Err(Uac2Error::InvalidDescriptor(
                "not format type II".to_string(),
            ));
        }
        let b_sam_freq_type = data[9];
        let mut sample_rates: Vec<u32> = Vec::new();
        if b_sam_freq_type == 0 {
            if data.len() >= 13 {
                sample_rates.push(read_u32_le(data, 10));
            }
        } else {
            let num_rates = b_sam_freq_type as usize;
            require_len(data, 10 + num_rates * 6)?;
            for i in 0..num_rates {
                sample_rates.push(read_u32_le(data, 10 + i * 6));
            }
        }
        let f = FormatTypeII {
            w_max_bit_rate: read_u16_le(data, 4),
            w_samples_per_frame: read_u16_le(data, 6),
            b_sam_freq_type,
            sample_rates,
        };
        validate_format_type_ii(&f)?;
        Ok(f)
    }

    pub fn parse_format_type_iii(&self, data: &[u8]) -> Result<FormatTypeIII, Uac2Error> {
        const LEN: usize = 6;
        require_len(data, LEN)?;
        if data[1] != USB_DT_CS_INTERFACE
            || data[2] != UAC2_FORMAT_TYPE
            || data[3] != UAC2_FORMAT_TYPE_III
        {
            return Err(Uac2Error::InvalidDescriptor(
                "not format type III".to_string(),
            ));
        }
        let f = FormatTypeIII {
            b_subslot_size: data[4],
            b_bit_resolution: data[5],
        };
        validate_format_type_iii(&f)?;
        Ok(f)
    }

    pub fn parse_endpoint_specific(&self, data: &[u8]) -> Result<EndpointSpecific, Uac2Error> {
        const LEN: usize = 5;
        require_len(data, LEN)?;
        if data[1] != USB_DT_CS_ENDPOINT {
            return Err(Uac2Error::InvalidDescriptor(
                "not CS endpoint".to_string(),
            ));
        }
        Ok(EndpointSpecific {
            b_endpoint_address: data[2],
            bm_attributes: data.get(3).copied().unwrap_or(0),
            b_lock_delay_units: data.get(4).copied().unwrap_or(0),
            w_lock_delay: if data.len() >= 7 {
                read_u16_le(data, 5)
            } else {
                0
            },
        })
    }
}

impl DescriptorParser for AudioStreamingParser {
    type Output = AudioStreamingDescriptor;

    fn parse(&self, data: &[u8]) -> Result<Self::Output, Uac2Error> {
        if data.len() < 4 {
            return Err(Uac2Error::InvalidDescriptor(
                "descriptor too short".to_string(),
            ));
        }
        // CS_ENDPOINT descriptors are on the endpoint, not interface
        if data[1] == USB_DT_CS_ENDPOINT {
            return self
                .parse_endpoint_specific(data)
                .map(AudioStreamingDescriptor::EndpointSpecific);
        }
        if data[1] != USB_DT_CS_INTERFACE {
            return Err(Uac2Error::InvalidDescriptor("not CS interface".to_string()));
        }
        match (data[2], data.get(3).copied().unwrap_or(0)) {
            (UAC2_AS_GENERAL, _) => self.parse_as_general(data),
            (UAC2_FORMAT_TYPE, UAC2_FORMAT_TYPE_I) => self
                .parse_format_type_i(data)
                .map(AudioStreamingDescriptor::FormatTypeI),
            (UAC2_FORMAT_TYPE, UAC2_FORMAT_TYPE_II) => self
                .parse_format_type_ii(data)
                .map(AudioStreamingDescriptor::FormatTypeII),
            (UAC2_FORMAT_TYPE, UAC2_FORMAT_TYPE_III) => self
                .parse_format_type_iii(data)
                .map(AudioStreamingDescriptor::FormatTypeIII),
            _ => Err(Uac2Error::InvalidDescriptor(format!(
                "unknown AS descriptor subtype {} {}",
                data[2],
                data.get(3).unwrap_or(&0)
            ))),
        }
    }
}
