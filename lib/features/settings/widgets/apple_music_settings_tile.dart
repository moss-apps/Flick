import 'package:flutter/material.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/services/apple_music/apple_music_settings.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AppleMusicSettingsTile extends StatefulWidget {
  const AppleMusicSettingsTile({super.key});

  @override
  State<AppleMusicSettingsTile> createState() => _AppleMusicSettingsTileState();
}

class _AppleMusicSettingsTileState extends State<AppleMusicSettingsTile> {
  final _settings = AppleMusicSettings();
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _settings.autoEnrichEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await _settings.setAutoEnrichEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return ToggleSetting(
      icon: LucideIcons.sparkles,
      title: 'Auto-identify untagged albums',
      subtitle:
          'After scanning, match files with missing tags against Apple Music. '
          'Only confident matches apply automatically.',
      value: _enabled,
      onChanged: _toggle,
    );
  }
}
