mod audio_control_parser;
mod audio_streaming_parser;
mod builders;
mod constants;
mod factory;
mod helpers;
mod iad_parser;
mod parse;
mod parser_trait;
mod types;
mod validation;

pub use audio_control_parser::AudioControlParser;
pub use audio_streaming_parser::AudioStreamingParser;
pub use builders::{FeatureUnitBuilder, FormatTypeIBuilder, FormatTypeIIBuilder};
pub use factory::DescriptorFactory;
pub use parse::{
    parse_ac_descriptor, parse_ac_interface_header, parse_ac_interface_header_v1,
    parse_as_descriptor, parse_as_general_descriptor, parse_as_interface_general,
    parse_clock_multiplier, parse_clock_selector, parse_clock_source, parse_effect_unit,
    parse_endpoint_specific, parse_extension_unit, parse_feature_unit, parse_format_type_i,
    parse_format_type_ii, parse_format_type_iii, parse_iad, parse_input_terminal, parse_mixer_unit,
    parse_output_terminal, parse_processing_unit, parse_selector_unit, DescriptorIter,
};
pub use parser_trait::DescriptorParser;
pub use types::*;
