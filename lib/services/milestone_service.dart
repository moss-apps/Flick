import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../data/repositories/recently_played_repository.dart';

enum MilestoneType { songs100, songs500, songs1000, hours10, hours50 }

extension MilestoneTypeX on MilestoneType {
  String get id => name;

  String get title {
    return switch (this) {
      MilestoneType.songs100 => '100 Songs',
      MilestoneType.songs500 => '500 Songs',
      MilestoneType.songs1000 => '1,000 Songs',
      MilestoneType.hours10 => '10 Hours',
      MilestoneType.hours50 => '50 Hours',
    };
  }

  String get shortLabel {
    return switch (this) {
      MilestoneType.songs100 => '100 songs',
      MilestoneType.songs500 => '500 songs',
      MilestoneType.songs1000 => '1,000 songs',
      MilestoneType.hours10 => '10 hours',
      MilestoneType.hours50 => '50 hours',
    };
  }

  String get message {
    return switch (this) {
      MilestoneType.songs100 =>
        "You've listened to 100 songs on Flick! If you're enjoying the app, a small donation helps keep the engine running and brings DSD playback closer.",
      MilestoneType.songs500 =>
        "500 songs and counting! Flick is built by a solo developer — consider fueling the next round of features on Ko-fi.",
      MilestoneType.songs1000 =>
        "1,000 songs deep in your Flick journey. Your support helps fund things like audio testing equipment and USB DAC improvements.",
      MilestoneType.hours10 =>
        "You've spent 10 hours with Flick. Time flies with great audio — if Flick adds value to your day, a donation helps keep it growing.",
      MilestoneType.hours50 =>
        "50 hours on Flick — that's some serious listening. Consider tipping the developer to help fund native DSD/DSF playback.",
    };
  }

  /// Per-tier accent color used for the milestone card border, icon badge, and
  /// collection tile accents.
  Color get tierColor {
    return switch (this) {
      MilestoneType.songs100 => AppColors.milestoneBronze,
      MilestoneType.songs500 => AppColors.milestoneSilver,
      MilestoneType.songs1000 => AppColors.milestoneGold,
      MilestoneType.hours10 => AppColors.milestoneSapphire,
      MilestoneType.hours50 => AppColors.milestoneAmethyst,
    };
  }

  /// Per-tier icon (Lucide). Picked to give each milestone a distinct identity.
  IconData get tierIcon {
    return switch (this) {
      MilestoneType.songs100 => LucideIcons.music,
      MilestoneType.songs500 => LucideIcons.headphones,
      MilestoneType.songs1000 => LucideIcons.disc3,
      MilestoneType.hours10 => LucideIcons.timer,
      MilestoneType.hours50 => LucideIcons.trophy,
    };
  }

  /// The threshold value this milestone represents (e.g. 100, 500, 1000, 10, 50).
  int get threshold {
    return switch (this) {
      MilestoneType.songs100 => 100,
      MilestoneType.songs500 => 500,
      MilestoneType.songs1000 => 1000,
      MilestoneType.hours10 => 10,
      MilestoneType.hours50 => 50,
    };
  }

  /// Whether the milestone is measured in songs (vs. hours).
  bool get isSongBased {
    return switch (this) {
      MilestoneType.songs100 ||
      MilestoneType.songs500 ||
      MilestoneType.songs1000 => true,
      MilestoneType.hours10 || MilestoneType.hours50 => false,
    };
  }

  /// True for the highest tier in each category — these are the "endgame"
  /// milestones and the popup won't tease a "next" one.
  bool get isTopTier {
    return this == MilestoneType.songs1000 || this == MilestoneType.hours50;
  }
}

class MilestoneRecord {
  final MilestoneType type;
  final DateTime achievedAt;

  const MilestoneRecord({required this.type, required this.achievedAt});

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'achievedAt': achievedAt.toIso8601String(),
  };

  factory MilestoneRecord.fromJson(Map<String, dynamic> json) {
    return MilestoneRecord(
      type: MilestoneType.values.firstWhere((e) => e.name == json['type']),
      achievedAt: DateTime.parse(json['achievedAt']),
    );
  }
}

class MilestoneService {
  static const _shownMilestonesKey = 'shown_milestones';
  static const _accumulatedListenSecondsKey = 'accumulated_listen_seconds';

  final RecentlyPlayedRepository? _repository;
  final Future<int> Function()? _playCountOverride;

  /// Tests can pass a `playCountOverride` to bypass the Isar-backed repository
  /// and inject a deterministic play count. When `playCountOverride` is
  /// supplied, the repository is not constructed (so unit tests don't need
  /// Isar initialized).
  MilestoneService({
    RecentlyPlayedRepository? repository,
    Future<int> Function()? playCountOverride,
  }) : _repository = playCountOverride == null
           ? (repository ?? RecentlyPlayedRepository())
           : repository,
       _playCountOverride = playCountOverride;

  Future<int> _getPlayCount() {
    final override = _playCountOverride;
    if (override != null) return override();
    return _repository!.getHistoryCount();
  }

  /// Exposed for the milestones screen (and the locked-tile bottom sheet) to
  /// render live progress without re-running the full next-milestone query.
  Future<int> getHistoryCount() => _getPlayCount();

  Future<int> getAccumulatedListenSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accumulatedListenSecondsKey) ?? 0;
  }

  Future<void> addListenSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_accumulatedListenSecondsKey) ?? 0;
    await prefs.setInt(_accumulatedListenSecondsKey, current + seconds);
  }

  Future<List<MilestoneRecord>> getShownMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shownMilestonesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MilestoneRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markMilestoneShown(MilestoneType type) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = await getShownMilestones();
    shown.add(MilestoneRecord(type: type, achievedAt: DateTime.now()));
    final raw = jsonEncode(shown.map((r) => r.toJson()).toList());
    await prefs.setString(_shownMilestonesKey, raw);
  }

  Future<bool> isMilestoneShown(MilestoneType type) async {
    final shown = await getShownMilestones();
    return shown.any((r) => r.type == type);
  }

  Future<MilestoneType?> checkMilestones() async {
    final playCount = await _getPlayCount();
    final listenSeconds = await getAccumulatedListenSeconds();
    final listenHours = listenSeconds ~/ 3600;

    if (playCount >= 1000 && !await isMilestoneShown(MilestoneType.songs1000)) {
      return MilestoneType.songs1000;
    }
    if (playCount >= 500 && !await isMilestoneShown(MilestoneType.songs500)) {
      return MilestoneType.songs500;
    }
    if (playCount >= 100 && !await isMilestoneShown(MilestoneType.songs100)) {
      return MilestoneType.songs100;
    }
    if (listenHours >= 50 && !await isMilestoneShown(MilestoneType.hours50)) {
      return MilestoneType.hours50;
    }
    if (listenHours >= 10 && !await isMilestoneShown(MilestoneType.hours10)) {
      return MilestoneType.hours10;
    }
    return null;
  }

  /// Returns the lowest-tier unshown milestone (across both groups) along with
  /// the units still needed to unlock it. Returns `next: null` once every
  /// milestone has been achieved.
  Future<({MilestoneType? next, int remaining})> getNextMilestone() async {
    final shown = await getShownMilestones();
    final shownSet = shown.map((r) => r.type).toSet();
    final playCount = await _getPlayCount();
    final listenSeconds = await getAccumulatedListenSeconds();
    final listenHours = listenSeconds ~/ 3600;

    for (final type in MilestoneType.values) {
      if (shownSet.contains(type)) continue;
      final current = type.isSongBased ? playCount : listenHours;
      final remaining = type.threshold - current;
      return (next: type, remaining: remaining < 0 ? 0 : remaining);
    }
    return (next: null, remaining: 0);
  }
}
