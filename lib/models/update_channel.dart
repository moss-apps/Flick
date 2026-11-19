/// Selects which GitHub release channel Flick offers updates from.
enum UpdateChannel {
  stable('stable'),
  beta('beta'),
  both('both');

  const UpdateChannel(this.storageValue);

  final String storageValue;

  bool get includesStable => this != UpdateChannel.beta;

  bool get includesBeta => this != UpdateChannel.stable;

  static UpdateChannel fromStorage(String? value) {
    for (final channel in values) {
      if (channel.storageValue == value) return channel;
    }
    return UpdateChannel.stable;
  }
}
