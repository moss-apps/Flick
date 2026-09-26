/// Cross-service flag: parametric EQ wants the Rust engine so the full
/// variable-band DSP chain runs instead of the device's fixed-band AudioEffect.
class EqEngineHint {
  EqEngineHint._();

  static bool parametricPeqActive = false;
}
