import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  final RecentlyPlayedRepository _repository = RecentlyPlayedRepository();

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
    final playCount = await _repository.getHistoryCount();
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
}
