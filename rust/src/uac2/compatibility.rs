use crate::uac2::constants::*;
use crate::uac2::descriptors::{
    parse_ac_descriptor, parse_as_interface_general, parse_format_type_i,
    AudioControlDescriptor, AudioStreamingDescriptor,
    ClockSource, DescriptorIter, DescriptorKind, EndpointSpecific, FeatureUnit,
    InputTerminal, OutputTerminal,
};
use crate::uac2::error::Uac2Error;
use crate::uac2::quirk::{QuirkDatabase, UsbAudioQuirk};
use crate::uac2::uac_version::UacVersion;
use rusb::{Device, DeviceHandle, Direction, Speed, SyncType, TransferType, UsageType, UsbContext};
use tracing::debug;

/// Maximum packet size multiplier for high-speed isochronous endpoints (µFrame).
const HS_MICROFRAME_CAP: usize = 1024;
const FS_FRAME_CAP: usize = 1023;

// ── Device Model ──

/// Fully parsed USB Audio Class device model.
/// Treats every DAC as a generic compliant device first; quirks are applied afterward.
pub struct GenericUsbAudioDevice {
    pub uac_version: UacVersion,
    pub bcd_adc: u16,
    pub ac_interfaces: Vec<AcInterfaceInfo>,
    pub as_interfaces: Vec<AsInterfaceInfo>,
    pub clock_sources: Vec<ClockSource>,
    pub input_terminals: Vec<InputTerminal>,
    pub output_terminals: Vec<OutputTerminal>,
    pub feature_units: Vec<FeatureUnit>,
    pub quirks: Vec<UsbAudioQuirk>,
}

#[derive(Debug, Clone)]
pub struct AcInterfaceInfo {
    pub interface_number: u8,
    pub sub_class: u8,
    pub descriptors: Vec<DescriptorKind>,
}

#[derive(Debug, Clone)]
pub struct AsInterfaceInfo {
    pub interface_number: u8,
    pub sub_class: u8,
    pub terminal_link: u8,
    pub alt_settings: Vec<AltSettingInfo>,
}

#[derive(Debug, Clone)]
pub struct AltSettingInfo {
    pub alt_setting: u8,
    pub format_tag: u16,
    pub channels: u16,
    pub subslot_size: u8,
    pub bit_resolution: u8,
    pub sample_rates: Vec<u32>,
    pub endpoints: Vec<EndpointInfo>,
}

#[derive(Debug, Clone)]
pub struct EndpointInfo {
    pub address: u8,
    pub direction: Direction,
    pub transfer_type: TransferType,
    pub sync_type: SyncType,
    pub usage_type: UsageType,
    pub max_packet_size: u16,
    pub interval: u8,
    pub service_interval_us: u32,
    pub refresh: u8,
    pub synch_address: u8,
    pub is_feedback: bool,
    pub is_data_endpoint: bool,
    pub endpoint_specific: Option<EndpointSpecific>,
}

impl GenericUsbAudioDevice {
    /// Build the generic model from USB config descriptors.
    pub fn from_device<T: UsbContext>(
        device: &Device<T>,
        handle: &DeviceHandle<T>,
    ) -> Result<Self, Uac2Error> {
        let config_desc = device.active_config_descriptor()?;
        let speed = device.speed();
        let device_desc = device.device_descriptor()?;
        let vendor_id = device_desc.vendor_id();
        let product_id = device_desc.product_id();
        // Grab product name via string descriptor for quirk matching.
        let product_name = handle
            .read_product_string_ascii(&device_desc)
            .unwrap_or_default();

        let mut uac_version = UacVersion::Unknown;
        let mut bcd_adc: u16 = 0;
        let mut ac_interfaces = Vec::new();
        let mut as_interfaces: Vec<AsInterfaceInfo> = Vec::new();
        let mut clock_sources = Vec::new();
        let mut input_terminals = Vec::new();
        let mut output_terminals = Vec::new();
        let mut feature_units = Vec::new();

        for interface in config_desc.interfaces() {
            for descriptor in interface.descriptors() {
                let class = descriptor.class_code();
                let sub_class = descriptor.sub_class_code();
                let iface_num = descriptor.interface_number();

                if class != USB_CLASS_AUDIO {
                    continue;
                }

                if sub_class == USB_SUBCLASS_AUDIOCONTROL {
                    let mut ac_desc = AcInterfaceInfo {
                        interface_number: iface_num,
                        sub_class,
                        descriptors: Vec::new(),
                    };

                    for extra in DescriptorIter::new(descriptor.extra()) {
                        match parse_ac_descriptor(extra) {
                            Ok(desc) => {
                                match &desc {
                                    AudioControlDescriptor::HeaderV2(h) => {
                                        bcd_adc = h.bcd_adc;
                                        uac_version = crate::uac2::uac_version::detect_uac_version(bcd_adc);
                                    }
                                    AudioControlDescriptor::HeaderV1(h) => {
                                        bcd_adc = h.bcd_adc;
                                        uac_version = UacVersion::V1_0;
                                    }
                                    AudioControlDescriptor::ClockSource(cs) => {
                                        clock_sources.push(cs.clone());
                                    }
                                    AudioControlDescriptor::InputTerminal(it) => {
                                        input_terminals.push(it.clone());
                                    }
                                    AudioControlDescriptor::OutputTerminal(ot) => {
                                        output_terminals.push(ot.clone());
                                    }
                                    AudioControlDescriptor::FeatureUnit(fu) => {
                                        feature_units.push(fu.clone());
                                    }
                                    _ => {}
                                }
                                ac_desc.descriptors.push(desc.into());
                            }
                            Err(_) => continue,
                        }
                    }

                    if !ac_desc.descriptors.is_empty() {
                        ac_interfaces.push(ac_desc);
                    }
                } else if sub_class == USB_SUBCLASS_AUDIOSTREAMING {
                    let mut as_iface = AsInterfaceInfo {
                        interface_number: iface_num,
                        sub_class,
                        terminal_link: 0,
                        alt_settings: Vec::new(),
                    };

                    // Parse AS General from the extra descriptors for terminal link.
                    for extra in DescriptorIter::new(descriptor.extra()) {
                        if let Ok(gen) = parse_as_interface_general(extra) {
                            as_iface.terminal_link = gen.b_terminal_link;
                            break;
                        }
                    }

                    let alt_setting = descriptor.setting_number();
                    let mut alt = AltSettingInfo {
                        alt_setting,
                        format_tag: FORMAT_TAG_PCM,
                        channels: 2,
                        subslot_size: 0,
                        bit_resolution: 0,
                        sample_rates: Vec::new(),
                        endpoints: Vec::new(),
                    };

                    // Parse format info from extra descriptors.
                    for extra in DescriptorIter::new(descriptor.extra()) {
                        if let Ok(gen) = parse_as_interface_general(extra) {
                            alt.format_tag = gen.w_format_tag;
                        }
                        if let Ok(fmt) = parse_format_type_i(extra) {
                            alt.subslot_size = fmt.b_subslot_size;
                            alt.bit_resolution = fmt.b_bit_resolution;
                            alt.sample_rates = fmt.sample_rates;
                        }
                    }

                    // Discover endpoints.
                    let service_interval =
                        service_interval_micros(speed, descriptor.interface_number(), &[]);
                    for endpoint in descriptor.endpoint_descriptors() {
                        let transfer_type = endpoint.transfer_type();
                        if transfer_type != TransferType::Isochronous
                            && transfer_type != TransferType::Interrupt
                        {
                            continue;
                        }

                        let ep_addr = endpoint.address();
                        let sync_type = endpoint.sync_type();
                        let usage_type = endpoint.usage_type();
                        let synch_address = endpoint.synch_address();
                        let is_data = usage_type == UsageType::Data
                            || usage_type == UsageType::FeedbackData;
                        let is_feedback = usage_type == UsageType::Feedback
                            || usage_type == UsageType::FeedbackData;

                        let ep_interval = endpoint.interval();
                        let service_interval_us = if ep_interval > 0 {
                            microframe_interval(speed, ep_interval)
                        } else {
                            service_interval
                        };

                        let _max_packet_bytes = effective_iso_packet_bytes(
                            endpoint.max_packet_size(),
                            speed,
                        );

                        // Parse endpoint-specific descriptor if present.
                        let mut ep_specific = None;
                        if let Some(extra) = endpoint.extra() {
                            for extra_chunk in DescriptorIter::new(extra) {
                                if let Ok(spec) =
                                    crate::uac2::descriptors::parse_endpoint_specific(extra_chunk)
                                {
                                    ep_specific = Some(spec);
                                    break;
                                }
                            }
                        }

                        alt.endpoints.push(EndpointInfo {
                            address: ep_addr,
                            direction: endpoint.direction(),
                            transfer_type,
                            sync_type,
                            usage_type,
                            max_packet_size: endpoint.max_packet_size(),
                            interval: ep_interval,
                            service_interval_us,
                            refresh: endpoint.refresh(),
                            synch_address,
                            is_feedback,
                            is_data_endpoint: is_data,
                            endpoint_specific: ep_specific,
                        });
                    }

                    // Merge into existing interface if already present.
                    if let Some(existing) = as_interfaces
                        .iter_mut()
                        .find(|i| i.interface_number == iface_num)
                    {
                        existing.alt_settings.push(alt);
                        existing.terminal_link = existing.terminal_link.max(as_iface.terminal_link);
                    } else {
                        as_iface.alt_settings.push(alt);
                        as_interfaces.push(as_iface);
                    }
                }
            }
        }

        // Sort alt settings.
        for as_iface in &mut as_interfaces {
            as_iface
                .alt_settings
                .sort_by_key(|a| (a.alt_setting, a.format_tag));
        }

        let quirks = crate::uac2::quirk::QUIRK_DATABASE.lookup(vendor_id, product_id, &product_name);

        debug!(
            uac_version = uac_version.as_str(),
            ac_count = ac_interfaces.len(),
            as_count = as_interfaces.len(),
            clock_count = clock_sources.len(),
            quirk_count = quirks.len(),
            "Generic USB Audio Device built"
        );

        Ok(Self {
            uac_version,
            bcd_adc,
            ac_interfaces,
            as_interfaces,
            clock_sources,
            input_terminals,
            output_terminals,
            feature_units,
            quirks,
        })
    }

    pub fn apply_quirks(
        &mut self,
        database: &QuirkDatabase,
        vendor_id: u16,
        product_id: u16,
        product_name: &str,
    ) {
        self.quirks = database.lookup(vendor_id, product_id, product_name);
    }

    // ── Descriptor-Driven Behavior Queries ──

    /// Find all data output endpoints that have a feedback endpoint paired via synch_address.
    pub fn has_feedback_endpoint(&self, interface_number: u8, alt_setting: u8) -> bool {
        self.find_feedback_endpoint(interface_number, alt_setting)
            .is_some()
    }

    pub fn find_feedback_endpoint(
        &self,
        interface_number: u8,
        alt_setting: u8,
    ) -> Option<&EndpointInfo> {
        let synch_address = self
            .data_endpoints_in_alt(interface_number, alt_setting)
            .iter()
            .filter(|ep| ep.direction == Direction::Out)
            .map(|ep| ep.synch_address)
            .find(|&addr| addr != 0)?;

        self.endpoints_in_alt(interface_number, alt_setting)
            .iter()
            .find(|ep| ep.address == synch_address && ep.direction == Direction::In)
            .copied()
            .or_else(|| {
                // Feedback endpoint on separate interface? Check all interfaces.
                self.as_interfaces.iter().find_map(|iface| {
                    iface
                        .alt_settings
                        .iter()
                        .find_map(|alt| alt.endpoints.iter().find(|ep| ep.address == synch_address))
                })
            })
    }

    pub fn endpoint_sync_type(
        &self,
        interface_number: u8,
        alt_setting: u8,
        ep_address: u8,
    ) -> Option<SyncType> {
        self.endpoints_in_alt(interface_number, alt_setting)
            .iter()
            .find(|ep| ep.address == ep_address)
            .map(|ep| ep.sync_type)
    }

    /// Returns true when the data endpoint uses asynchronous sync (has a feedback endpoint).
    pub fn is_async_endpoint(
        &self,
        interface_number: u8,
        alt_setting: u8,
        ep_address: u8,
    ) -> bool {
        self.endpoints_in_alt(interface_number, alt_setting)
            .iter()
            .find(|ep| ep.address == ep_address)
            .is_some_and(|ep| ep.sync_type == SyncType::Asynchronous)
            || self.has_feedback_endpoint(interface_number, alt_setting)
    }

    pub fn is_adaptive_endpoint(
        &self,
        interface_number: u8,
        alt_setting: u8,
        ep_address: u8,
    ) -> bool {
        self.endpoints_in_alt(interface_number, alt_setting)
            .iter()
            .find(|ep| ep.address == ep_address)
            .is_some_and(|ep| matches!(ep.sync_type, SyncType::Adaptive))
    }

    /// Find all alt settings that support DSD format (format_tag == FORMAT_TAG_DSD).
    pub fn find_dsd_alt_settings(&self) -> Vec<DsdAltSettingRef<'_>> {
        self.as_interfaces
            .iter()
            .flat_map(|iface| {
                iface.alt_settings.iter().filter_map(|alt| {
                    if alt.format_tag == FORMAT_TAG_DSD {
                        Some(DsdAltSettingRef {
                            interface_number: iface.interface_number,
                            alt_setting: alt.alt_setting,
                            format_tag: alt.format_tag,
                            subslot_size: alt.subslot_size,
                            bit_resolution: alt.bit_resolution,
                            channels: alt.channels,
                            sample_rate: alt.sample_rates.first().copied(),
                            endpoints: &alt.endpoints,
                        })
                    } else {
                        None
                    }
                })
            })
            .collect()
    }

    /// Find best alt setting for a given rate, bit depth, and channel count.
    /// Uses descriptor-driven scoring: match rate > match depth > highest max_packet.
    pub fn best_alt_for_rate(
        &self,
        target_rate: u32,
        target_bit_depth: u8,
        target_channels: u16,
    ) -> Option<AltSettingRef<'_>> {
        let mut candidates: Vec<AltSettingRef<'_>> = Vec::new();

        for iface in &self.as_interfaces {
            for alt in &iface.alt_settings {
                if alt.alt_setting == 0 {
                    continue;
                }
                if alt.format_tag != FORMAT_TAG_PCM {
                    continue;
                }
                if alt.channels != target_channels {
                    continue;
                }
                if alt.bit_resolution != target_bit_depth {
                    continue;
                }
                // Rate match: exact match preferred, then any range match.
                let rate_matches = alt.sample_rates.is_empty()
                    || alt.sample_rates.contains(&target_rate)
                    || alt.sample_rates.iter().any(|&r| r == target_rate);

                if !rate_matches && !alt.sample_rates.is_empty() {
                    continue;
                }

                let has_data_ep = alt.endpoints.iter().any(|ep| ep.is_data_endpoint);
                if !has_data_ep {
                    continue;
                }

                candidates.push(AltSettingRef {
                    interface_number: iface.interface_number,
                    alt_setting: alt.alt_setting,
                    format_tag: alt.format_tag,
                    subslot_size: alt.subslot_size,
                    bit_resolution: alt.bit_resolution,
                    channels: alt.channels,
                    endpoints: &alt.endpoints,
                    sample_rates: &alt.sample_rates,
                });
            }
        }

        // Score: exact rate match + highest max_packet.
        candidates.sort_by_key(|c| {
            let exact_rate = u64::from(c.sample_rates.contains(&target_rate));
            let max_pkt = c
                .endpoints
                .iter()
                .filter(|ep| ep.is_data_endpoint)
                .map(|ep| ep.max_packet_size)
                .max()
                .unwrap_or(0) as u64;
            (exact_rate, max_pkt, c.alt_setting as u64)
        });
        candidates.last().copied()
    }

    /// Find all output data endpoints in a specific alt setting.
    pub fn data_endpoints_in_alt(
        &self,
        interface_number: u8,
        alt_setting: u8,
    ) -> Vec<&EndpointInfo> {
        self.endpoints_in_alt(interface_number, alt_setting)
            .into_iter()
            .filter(|ep| ep.is_data_endpoint && ep.direction == Direction::Out)
            .collect()
    }

    fn endpoints_in_alt(&self, interface_number: u8, alt_setting: u8) -> Vec<&EndpointInfo> {
        self.as_interfaces
            .iter()
            .filter(|iface| iface.interface_number == interface_number)
            .flat_map(|iface| iface.alt_settings.iter())
            .filter(|alt| alt.alt_setting == alt_setting)
            .flat_map(|alt| alt.endpoints.iter())
            .collect()
    }

    /// Get the best clock source for a given terminal link.
    pub fn clock_source_for_terminal(&self, terminal_link: u8) -> Option<&ClockSource> {
        // Walk terminal topology: terminal -> bCSourceID -> clock_id
        let input_term = self
            .input_terminals
            .iter()
            .find(|it| it.b_terminal_id == terminal_link);
        if let Some(it) = input_term {
            let cs_id = it.b_c_source_id;
            return self.clock_sources.iter().find(|cs| cs.b_clock_id == cs_id);
        }
        // Fallback: first clock source
        self.clock_sources.first()
    }

    /// Get the AC interface number where this clock source lives.
    /// Returns (interface_number, clock_id).
    pub fn find_clock_location(&self, clock: &ClockSource) -> Option<(u8, u8)> {
        self.ac_interfaces
            .iter()
            .find_map(|ac_iface| {
                ac_iface
                    .descriptors
                    .iter()
                    .any(|d| {
                        matches!(d, DescriptorKind::AudioControl(
                            AudioControlDescriptor::ClockSource(cs)
                        ) if cs.b_clock_id == clock.b_clock_id)
                    })
                    .then_some(ac_iface.interface_number)
            })
            .map(|num| (num, clock.b_clock_id))
    }

    pub fn quirk_active(&self, quirk: UsbAudioQuirk) -> bool {
        self.quirks.contains(&quirk)
    }
}

// ── Helper types ──

#[derive(Debug, Clone, Copy)]
pub struct AltSettingRef<'a> {
    pub interface_number: u8,
    pub alt_setting: u8,
    pub format_tag: u16,
    pub subslot_size: u8,
    pub bit_resolution: u8,
    pub channels: u16,
    pub endpoints: &'a [EndpointInfo],
    pub sample_rates: &'a [u32],
}

#[derive(Debug, Clone, Copy)]
pub struct DsdAltSettingRef<'a> {
    pub interface_number: u8,
    pub alt_setting: u8,
    pub format_tag: u16,
    pub subslot_size: u8,
    pub bit_resolution: u8,
    pub channels: u16,
    pub sample_rate: Option<u32>,
    pub endpoints: &'a [EndpointInfo],
}

// ── USB Speed Helpers ──

fn service_interval_micros(speed: Speed, _iface: u8, _pairs: &[u8]) -> u32 {
    match speed {
        Speed::High | Speed::Super => 125,
        Speed::Full => 1_000,
        Speed::Low => 10_000,
        _ => 1_000,
    }
}

/// Convert bInterval to microseconds based on speed tier.
fn microframe_interval(speed: Speed, interval: u8) -> u32 {
    match speed {
        Speed::High | Speed::Super => {
            // Interval is in microframes (125µs), value = 2^(bInterval-1)
            let exp = interval.saturating_sub(1).min(16);
            125u32 * (1u32 << exp)
        }
        Speed::Full => {
            // Interval in frames (1ms), value = 2^(bInterval-1)
            let exp = interval.saturating_sub(1).min(16);
            1000u32 * (1u32 << exp)
        }
        Speed::Low => {
            let exp = interval.saturating_sub(1).min(16);
            10_000u32 * (1u32 << exp)
        }
        _ => 1000,
    }
}

fn effective_iso_packet_bytes(max_packet_size: u16, speed: Speed) -> usize {
    match speed {
        Speed::High | Speed::Super => {
            // wMaxPacketSize bits 0-10: max packet size per microframe
            // bits 11-12: additional transactions per microframe
            let size = (max_packet_size & 0x07FF) as usize;
            let extra = ((max_packet_size >> 11) & 0x03) as usize;
            (size * (extra + 1)).min(HS_MICROFRAME_CAP)
        }
        Speed::Full => (max_packet_size as usize).min(FS_FRAME_CAP),
        _ => max_packet_size as usize,
    }
}

impl From<AudioControlDescriptor> for DescriptorKind {
    fn from(desc: AudioControlDescriptor) -> Self {
        DescriptorKind::AudioControl(desc)
    }
}

impl From<AudioStreamingDescriptor> for DescriptorKind {
    fn from(desc: AudioStreamingDescriptor) -> Self {
        DescriptorKind::AudioStreaming(desc)
    }
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quirk_check_on_empty_device() {
        let db = crate::uac2::quirk::QUIRK_DATABASE.lookup(0x0000, 0x0000, "empty");
        assert!(db.is_empty());
    }

    #[test]
    fn dawn_pro_known_quirk() {
        let db = crate::uac2::quirk::QUIRK_DATABASE.lookup(12230, 61546, "MOONDROP Dawn Pro");
        assert!(!db.is_empty());
        assert!(db.contains(&UsbAudioQuirk::RequireVerifiedRate));
    }
}
