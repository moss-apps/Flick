import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/providers/apple_music_provider.dart';
import 'package:flick/services/apple_music/apple_music_settings.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/l10n/settings_l10n.dart';

class AppleMusicSettingsTile extends ConsumerStatefulWidget {
  const AppleMusicSettingsTile({super.key});

  @override
  ConsumerState<AppleMusicSettingsTile> createState() =>
      _AppleMusicSettingsTileState();
}

class _AppleMusicSettingsTileState
    extends ConsumerState<AppleMusicSettingsTile> {
  final _settings = AppleMusicSettings();
  bool _autoEnrichEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _settings.autoEnrichEnabled();
    if (!mounted) return;
    setState(() => _autoEnrichEnabled = enabled);
  }

  Future<void> _toggleAutoEnrich(bool value) async {
    setState(() => _autoEnrichEnabled = value);
    await _settings.setAutoEnrichEnabled(value);
  }

  Future<void> _togglePageInfo(bool value) {
    return ref
        .read(appleMusicPageInfoEnabledProvider.notifier)
        .setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final pageInfoEnabled =
        ref.watch(appleMusicPageInfoEnabledProvider).value ?? true;
    return Column(
      children: [
        ToggleSetting(
          icon: LucideIcons.globe,
          title: l10n.englishForFilipino.onlineArtistAlbumInformation,
          subtitle: l10n.showAppleMusicBiographiesRecommendationsAnd,
          value: pageInfoEnabled,
          onChanged: _togglePageInfo,
        ),
        const SettingsDivider(),
        ToggleSetting(
          icon: LucideIcons.sparkles,
          title: l10n.englishForFilipino.autoIdentifyUntaggedAlbums,
          subtitle: l10n.afterScanningMatchFilesWithMissing,
          value: _autoEnrichEnabled,
          onChanged: _toggleAutoEnrich,
        ),
      ],
    );
  }
}
