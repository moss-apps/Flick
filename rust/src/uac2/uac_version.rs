use crate::uac2::constants::*;

pub fn detect_uac_version(bcd_adc: u16) -> UacVersion {
    if bcd_adc >= UAC2_BCD_ADC {
        UacVersion::V2_0
    } else if bcd_adc >= UAC1_BCD_ADC {
        UacVersion::V1_0
    } else {
        UacVersion::Unknown
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UacVersion {
    V1_0,
    V2_0,
    Unknown,
}

impl UacVersion {
    pub fn is_uac1(self) -> bool {
        matches!(self, Self::V1_0)
    }

    pub fn is_uac2_or_newer(self) -> bool {
        matches!(self, Self::V2_0)
    }

    pub fn from_interface_descriptor(extra: &[u8]) -> Option<Self> {
        use crate::uac2::descriptors::DescriptorIter;
        for chunk in DescriptorIter::new(extra) {
            if chunk.len() < 4 {
                continue;
            }
            if chunk[1] == USB_DT_CS_INTERFACE
                && (chunk[2] == UAC_AC_HEADER || chunk[2] == UAC2_AC_HEADER)
            {
                if chunk.len() >= 6 {
                    let bcd_adc = u16::from_le_bytes([chunk[4], chunk[5]]);
                    return Some(detect_uac_version(bcd_adc));
                }
                if chunk.len() >= 4 {
                    let bcd_adc = u16::from_le_bytes([chunk[3], chunk[4]]);
                    return Some(detect_uac_version(bcd_adc));
                }
            }
        }
        None
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::V1_0 => "UAC 1.0",
            Self::V2_0 => "UAC 2.0",
            Self::Unknown => "Unknown",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uac1_bcd_adc() {
        assert_eq!(detect_uac_version(0x0100), UacVersion::V1_0);
    }

    #[test]
    fn uac2_bcd_adc() {
        assert_eq!(detect_uac_version(0x0200), UacVersion::V2_0);
    }

    #[test]
    fn unknown_bcd_adc() {
        assert_eq!(detect_uac_version(0x0000), UacVersion::Unknown);
    }
}
