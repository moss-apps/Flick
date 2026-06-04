use super::constants::*;
use super::helpers::{read_u16_le, read_u32_le, require_len};
use super::parser_trait::DescriptorParser;
use super::types::*;
use super::validation::{
    validate_ac_interface_header, validate_feature_unit, validate_input_terminal,
    validate_output_terminal,
};
use crate::uac2::error::Uac2Error;

pub struct AudioControlParser;

impl AudioControlParser {
    pub fn parse_ac_header(&self, data: &[u8]) -> Result<AcInterfaceHeader, Uac2Error> {
        const HEADER_LEN: usize = 9;
        require_len(data, HEADER_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_AC_HEADER {
            return Err(Uac2Error::InvalidDescriptor("not CS_AC header".to_string()));
        }
        let h = AcInterfaceHeader {
            bcd_adc: read_u16_le(data, 3),
            b_category: data[5],
            w_total_length: read_u16_le(data, 6),
            bm_controls: read_u16_le(data, 8),
        };
        validate_ac_interface_header(&h)?;
        Ok(h)
    }

    pub fn parse_ac_header_v1(&self, data: &[u8]) -> Result<AcInterfaceHeaderV1, Uac2Error> {
        require_len(data, 9)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC_AC_HEADER {
            return Err(Uac2Error::InvalidDescriptor("not UAC1 AC header".to_string()));
        }
        let bcd_adc = read_u16_le(data, 3);
        let w_total_length = read_u16_le(data, 5);
        let b_in_collection = data[7];
        let len = data[0] as usize;
        let ba_interface_nr: Vec<u8> = data[8..len].to_vec();
        Ok(AcInterfaceHeaderV1 {
            bcd_adc,
            w_total_length,
            b_in_collection,
            ba_interface_nr,
        })
    }

    fn detect_and_parse_ac_header(&self, data: &[u8]) -> Result<AudioControlDescriptor, Uac2Error> {
        if data.len() >= 9 {
            // UAC 2.0 header has bCategory at byte 5; for UAC 1.0 the bCollectors field is different
            // UAC 1.0 layout: [0]=len [1]=DT_CS_IFACE [2]=HEADER [3-4]=bcdADC [5-6]=wTotalLength [7]=bInCollection [8+]=baInterfaceNr
            // UAC 2.0 layout: [0]=len [1]=DT_CS_IFACE [2]=HEADER [3-4]=bcdADC [5]=bCategory [6-7]=wTotalLength [8-9]=bmControls
            let _bcd_adc = read_u16_le(data, 3);
            let uac1_len = 8 + data.get(7).copied().unwrap_or(0) as usize;
            if data[0] as usize == uac1_len && data.len() >= uac1_len {
                return self
                    .parse_ac_header_v1(data)
                    .map(AudioControlDescriptor::HeaderV1);
            }
            self.parse_ac_header(data)
                .map(AudioControlDescriptor::HeaderV2)
        } else {
            self.parse_ac_header(data)
                .map(AudioControlDescriptor::HeaderV2)
        }
    }

    pub fn parse_input_terminal(&self, data: &[u8]) -> Result<InputTerminal, Uac2Error> {
        const LEN: usize = 15;
        require_len(data, LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_INPUT_TERMINAL {
            return Err(Uac2Error::InvalidDescriptor(
                "not input terminal".to_string(),
            ));
        }
        let t = InputTerminal {
            b_terminal_id: data[3],
            w_terminal_type: read_u16_le(data, 4),
            b_assoc_terminal: data[6],
            b_c_source_id: data[7],
            b_nr_channels: read_u16_le(data, 8),
            w_channel_config: read_u32_le(data, 10),
            i_terminal: data[14],
        };
        validate_input_terminal(&t)?;
        Ok(t)
    }

    pub fn parse_output_terminal(&self, data: &[u8]) -> Result<OutputTerminal, Uac2Error> {
        const LEN: usize = 9;
        require_len(data, LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_OUTPUT_TERMINAL {
            return Err(Uac2Error::InvalidDescriptor(
                "not output terminal".to_string(),
            ));
        }
        let t = OutputTerminal {
            b_terminal_id: data[3],
            w_terminal_type: read_u16_le(data, 4),
            b_assoc_terminal: data[6],
            b_source_id: data[7],
            i_terminal: data[8],
        };
        validate_output_terminal(&t)?;
        Ok(t)
    }

    pub fn parse_feature_unit(&self, data: &[u8]) -> Result<FeatureUnit, Uac2Error> {
        const MIN_LEN: usize = 7;
        require_len(data, MIN_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_FEATURE_UNIT {
            return Err(Uac2Error::InvalidDescriptor("not feature unit".to_string()));
        }
        let len = data[0] as usize;
        if len < MIN_LEN || (len - 7) % 4 != 0 {
            return Err(Uac2Error::InvalidDescriptor(
                "invalid feature unit length".to_string(),
            ));
        }
        let n = (len - 7) / 4;
        require_len(data, len)?;
        let bma_controls: Vec<u32> = (0..n).map(|i| read_u32_le(data, 7 + i * 4)).collect();
        let f = FeatureUnit {
            b_unit_id: data[3],
            b_source_id: data[4],
            b_control_size: data[5],
            bma_controls,
        };
        validate_feature_unit(&f)?;
        Ok(f)
    }

    pub fn parse_clock_source(&self, data: &[u8]) -> Result<ClockSource, Uac2Error> {
        const LEN: usize = 8;
        require_len(data, LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_CLOCK_SOURCE {
            return Err(Uac2Error::InvalidDescriptor(
                "not clock source".to_string(),
            ));
        }
        Ok(ClockSource {
            b_clock_id: data[3],
            bm_attributes: data[4],
            bm_controls: data[5],
            b_assoc_terminal: data[6],
            i_clock_source: data[7],
        })
    }

    pub fn parse_clock_selector(&self, data: &[u8]) -> Result<ClockSelector, Uac2Error> {
        const MIN_LEN: usize = 7;
        require_len(data, MIN_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_CLOCK_SELECTOR {
            return Err(Uac2Error::InvalidDescriptor(
                "not clock selector".to_string(),
            ));
        }
        let len = data[0] as usize;
        require_len(data, len)?;
        let b_nr_in_pins = data[5];
        let expected_len = 7 + b_nr_in_pins as usize;
        if len < expected_len {
            return Err(Uac2Error::InvalidDescriptor(
                "clock selector length mismatch".to_string(),
            ));
        }
        let ba_c_source_id: Vec<u8> = data[6..6 + b_nr_in_pins as usize].to_vec();
        let bm_controls_offset = 6 + b_nr_in_pins as usize;
        let bm_controls = data.get(bm_controls_offset).copied().unwrap_or(0);
        let i_clock_selector = data.get(bm_controls_offset + 1).copied().unwrap_or(0);
        Ok(ClockSelector {
            b_clock_id: data[3],
            b_nr_in_pins,
            ba_c_source_id,
            bm_controls,
            i_clock_selector,
        })
    }

    pub fn parse_clock_multiplier(&self, data: &[u8]) -> Result<ClockMultiplier, Uac2Error> {
        const LEN: usize = 7;
        require_len(data, LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC2_CLOCK_MULTIPLIER {
            return Err(Uac2Error::InvalidDescriptor(
                "not clock multiplier".to_string(),
            ));
        }
        Ok(ClockMultiplier {
            b_clock_id: data[3],
            b_c_source_id: data[4],
            bm_controls: data[5],
            i_clock_multiplier: data[6],
        })
    }

    pub fn parse_mixer_unit(&self, data: &[u8]) -> Result<MixerUnit, Uac2Error> {
        const MIN_LEN: usize = 10;
        require_len(data, MIN_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC_MIXER_UNIT {
            return Err(Uac2Error::InvalidDescriptor("not mixer unit".to_string()));
        }
        let len = data[0] as usize;
        require_len(data, len)?;
        let b_nr_in_pins = data[5];
        // For UAC1: fixed length; we'll be lenient
        let ba_source_id: Vec<u8> = data[6..6 + b_nr_in_pins as usize].to_vec();
        let channels_offset = 6 + b_nr_in_pins as usize;
        let b_nr_channels = if channels_offset + 1 < len {
            read_u16_le(data, channels_offset)
        } else {
            2
        };
        let w_channel_config = if channels_offset + 3 < len {
            read_u32_le(data, channels_offset + 2)
        } else {
            0
        };
        let i_mixer_offset = channels_offset + 6;
        let i_mixer = data.get(i_mixer_offset).copied().unwrap_or(0);
        let bm_controls: Vec<u8> = data[i_mixer_offset + 1..len].to_vec();
        Ok(MixerUnit {
            b_unit_id: data[3],
            b_nr_in_pins,
            ba_source_id,
            b_nr_channels,
            w_channel_config,
            i_mixer,
            bm_controls,
        })
    }

    pub fn parse_selector_unit(&self, data: &[u8]) -> Result<SelectorUnit, Uac2Error> {
        const MIN_LEN: usize = 6;
        require_len(data, MIN_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC_SELECTOR_UNIT {
            return Err(Uac2Error::InvalidDescriptor(
                "not selector unit".to_string(),
            ));
        }
        let len = data[0] as usize;
        require_len(data, len)?;
        let b_nr_in_pins = data[5];
        let ba_source_id: Vec<u8> = data[6..6 + b_nr_in_pins as usize].to_vec();
        let i_sel_offset = 6 + b_nr_in_pins as usize;
        let i_selector = data.get(i_sel_offset).copied().unwrap_or(0);
        let bm_controls = data.get(i_sel_offset + 1).copied();
        Ok(SelectorUnit {
            b_unit_id: data[3],
            b_nr_in_pins,
            ba_source_id,
            i_selector,
            bm_controls,
        })
    }

    pub fn parse_effect_unit(&self, data: &[u8]) -> Result<EffectUnit, Uac2Error> {
        const LEN: usize = 8;
        require_len(data, LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC_EFFECT_UNIT {
            return Err(Uac2Error::InvalidDescriptor("not effect unit".to_string()));
        }
        Ok(EffectUnit {
            b_unit_id: data[3],
            b_source_id: data[4],
            b_effect_id: read_u16_le(data, 5),
            i_effect: data[7],
        })
    }

    pub fn parse_processing_unit(&self, data: &[u8]) -> Result<ProcessingUnit, Uac2Error> {
        const MIN_LEN: usize = 10;
        require_len(data, MIN_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC_PROCESSING_UNIT {
            return Err(Uac2Error::InvalidDescriptor(
                "not processing unit".to_string(),
            ));
        }
        let len = data[0] as usize;
        require_len(data, len)?;
        let b_nr_channels = read_u16_le(data, 7);
        let w_channel_config = read_u32_le(data, 9);
        let i_processing = data.get(13).copied().unwrap_or(0);
        let bm_controls = data[14..len].to_vec();
        Ok(ProcessingUnit {
            b_unit_id: data[3],
            b_source_id: data[4],
            w_process_type: read_u16_le(data, 5),
            b_nr_channels,
            w_channel_config,
            i_processing,
            bm_controls,
        })
    }

    pub fn parse_extension_unit(&self, data: &[u8]) -> Result<ExtensionUnit, Uac2Error> {
        const MIN_LEN: usize = 13;
        require_len(data, MIN_LEN)?;
        if data[1] != USB_DT_CS_INTERFACE || data[2] != UAC_EXTENSION_UNIT {
            return Err(Uac2Error::InvalidDescriptor(
                "not extension unit".to_string(),
            ));
        }
        let len = data[0] as usize;
        require_len(data, len)?;
        let b_nr_in_pins = data[7];
        let ba_source_id: Vec<u8> = data[8..8 + b_nr_in_pins as usize].to_vec();
        let ch_offset = 8 + b_nr_in_pins as usize;
        let b_nr_channels = read_u16_le(data, ch_offset);
        let w_channel_config = read_u32_le(data, ch_offset + 2);
        let i_extension = data.get(ch_offset + 6).copied().unwrap_or(0);
        let bm_controls = data[ch_offset + 7..len].to_vec();
        Ok(ExtensionUnit {
            b_unit_id: data[3],
            w_extension_code: read_u16_le(data, 5),
            b_nr_in_pins,
            ba_source_id,
            b_nr_channels,
            w_channel_config,
            i_extension,
            bm_controls,
        })
    }
}

impl DescriptorParser for AudioControlParser {
    type Output = AudioControlDescriptor;

    fn parse(&self, data: &[u8]) -> Result<Self::Output, Uac2Error> {
        if data.len() < 3 {
            return Err(Uac2Error::InvalidDescriptor(
                "descriptor too short".to_string(),
            ));
        }
        if data[1] != USB_DT_CS_INTERFACE {
            return Err(Uac2Error::InvalidDescriptor("not CS interface".to_string()));
        }
        match data[2] {
            UAC_AC_HEADER => self.detect_and_parse_ac_header(data),
            UAC_INPUT_TERMINAL => self
                .parse_input_terminal(data)
                .map(AudioControlDescriptor::InputTerminal),
            UAC_OUTPUT_TERMINAL => self
                .parse_output_terminal(data)
                .map(AudioControlDescriptor::OutputTerminal),
            UAC_FEATURE_UNIT => self
                .parse_feature_unit(data)
                .map(AudioControlDescriptor::FeatureUnit),
            UAC2_CLOCK_SOURCE => self
                .parse_clock_source(data)
                .map(AudioControlDescriptor::ClockSource),
            UAC2_CLOCK_SELECTOR => self
                .parse_clock_selector(data)
                .map(AudioControlDescriptor::ClockSelector),
            UAC2_CLOCK_MULTIPLIER => self
                .parse_clock_multiplier(data)
                .map(AudioControlDescriptor::ClockMultiplier),
            UAC_MIXER_UNIT => self
                .parse_mixer_unit(data)
                .map(AudioControlDescriptor::MixerUnit),
            UAC_SELECTOR_UNIT => self
                .parse_selector_unit(data)
                .map(AudioControlDescriptor::SelectorUnit),
            UAC_EFFECT_UNIT => self
                .parse_effect_unit(data)
                .map(AudioControlDescriptor::EffectUnit),
            UAC_PROCESSING_UNIT => self
                .parse_processing_unit(data)
                .map(AudioControlDescriptor::ProcessingUnit),
            UAC_EXTENSION_UNIT => self
                .parse_extension_unit(data)
                .map(AudioControlDescriptor::ExtensionUnit),
            _ => Err(Uac2Error::InvalidDescriptor(format!(
                "unknown AC descriptor subtype {}",
                data[2]
            ))),
        }
    }
}
