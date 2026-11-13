/// Parameter ranges supported by the PEQ editor, imports and AutoEq catalog.
/// Keep the band count and Q range in sync with Rust's audio/equalizer.rs.
abstract final class EqLimits {
  static const minFrequencyHz = 20.0;
  static const maxFrequencyHz = 20000.0;
  static const minGainDb = -20.0;
  static const maxGainDb = 20.0;
  static const minQ = 0.1;
  static const maxQ = 20.0;
  static const minPreampDb = -24.0;
  static const maxPreampDb = 24.0;
  static const maxBands = 31;
}
