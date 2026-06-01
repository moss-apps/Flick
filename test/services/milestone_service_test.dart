import 'package:flick/services/milestone_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  MilestoneService buildService({int playCount = 0}) {
    return MilestoneService(playCountOverride: () async => playCount);
  }

  group('MilestoneTypeX', () {
    test('every tier has a title, message, color, and icon', () {
      for (final type in MilestoneType.values) {
        expect(type.title, isNotEmpty, reason: '${type.name} title');
        expect(type.message, isNotEmpty, reason: '${type.name} message');
        expect(type.shortLabel, isNotEmpty, reason: '${type.name} shortLabel');
        expect(type.tierColor, isA<Color>());
        expect(type.tierIcon, isA<IconData>());
        expect(type.threshold, greaterThan(0));
      }
    });

    test('top-tier flag is set only for the highest song and hour tiers', () {
      expect(MilestoneType.songs1000.isTopTier, isTrue);
      expect(MilestoneType.hours50.isTopTier, isTrue);
      expect(MilestoneType.songs100.isTopTier, isFalse);
      expect(MilestoneType.songs500.isTopTier, isFalse);
      expect(MilestoneType.hours10.isTopTier, isFalse);
    });

    test('isSongBased is true for song tiers and false for hour tiers', () {
      expect(MilestoneType.songs100.isSongBased, isTrue);
      expect(MilestoneType.songs500.isSongBased, isTrue);
      expect(MilestoneType.songs1000.isSongBased, isTrue);
      expect(MilestoneType.hours10.isSongBased, isFalse);
      expect(MilestoneType.hours50.isSongBased, isFalse);
    });
  });

  group('MilestoneRecord', () {
    test('round-trips through JSON', () {
      final record = MilestoneRecord(
        type: MilestoneType.songs500,
        achievedAt: DateTime.utc(2026, 6, 1, 12, 30),
      );
      final json = record.toJson();
      final restored = MilestoneRecord.fromJson(json);
      expect(restored.type, MilestoneType.songs500);
      expect(restored.achievedAt, DateTime.utc(2026, 6, 1, 12, 30));
    });
  });

  group('MilestoneService storage', () {
    test('addListenSeconds accumulates', () async {
      final service = buildService();
      await service.addListenSeconds(120);
      await service.addListenSeconds(240);
      expect(await service.getAccumulatedListenSeconds(), 360);
    });

    test(
      'markMilestoneShown persists and isMilestoneShown reads it back',
      () async {
        final service = buildService();
        expect(await service.isMilestoneShown(MilestoneType.songs100), isFalse);
        await service.markMilestoneShown(MilestoneType.songs100);
        expect(await service.isMilestoneShown(MilestoneType.songs100), isTrue);
        expect(await service.isMilestoneShown(MilestoneType.songs500), isFalse);
      },
    );

    test(
      'getShownMilestones returns multiple records in insertion order',
      () async {
        final service = buildService();
        await service.markMilestoneShown(MilestoneType.songs100);
        await service.markMilestoneShown(MilestoneType.hours10);
        final records = await service.getShownMilestones();
        expect(records, hasLength(2));
        expect(records.first.type, MilestoneType.songs100);
        expect(records.last.type, MilestoneType.hours10);
      },
    );
  });

  group('MilestoneService.checkMilestones', () {
    test('returns null when nothing has been listened to', () async {
      final service = buildService();
      expect(await service.checkMilestones(), isNull);
    });

    test('returns songs100 at exactly 100 plays', () async {
      final service = buildService(playCount: 100);
      expect(await service.checkMilestones(), MilestoneType.songs100);
    });

    test('prefers songs1000 over songs500 over songs100', () async {
      var service = buildService(playCount: 1000);
      expect(await service.checkMilestones(), MilestoneType.songs1000);
      await service.markMilestoneShown(MilestoneType.songs1000);

      service = buildService(playCount: 500);
      expect(await service.checkMilestones(), MilestoneType.songs500);
      await service.markMilestoneShown(MilestoneType.songs500);

      service = buildService(playCount: 100);
      expect(await service.checkMilestones(), MilestoneType.songs100);
    });

    test('returns hours10 at 10 hours of accumulated listening', () async {
      final service = buildService();
      await service.addListenSeconds(10 * 3600);
      expect(await service.checkMilestones(), MilestoneType.hours10);
    });

    test('does not return a milestone that was already shown', () async {
      final service = buildService(playCount: 200);
      await service.markMilestoneShown(MilestoneType.songs100);
      expect(await service.checkMilestones(), isNull);
    });
  });

  group('MilestoneService.getNextMilestone', () {
    test(
      'returns the lowest unshown tier with correct remaining songs',
      () async {
        final service = buildService(playCount: 80);
        final next = await service.getNextMilestone();
        expect(next.next, MilestoneType.songs100);
        expect(next.remaining, 20);
      },
    );

    test('switches to hours10 once all song tiers are shown', () async {
      final service = buildService(playCount: 9999);
      await service.markMilestoneShown(MilestoneType.songs100);
      await service.markMilestoneShown(MilestoneType.songs500);
      await service.markMilestoneShown(MilestoneType.songs1000);
      await service.addListenSeconds(5 * 3600);

      final next = await service.getNextMilestone();
      expect(next.next, MilestoneType.hours10);
      expect(next.remaining, 5);
    });

    test('returns next=null when every milestone is shown', () async {
      final service = buildService(playCount: 9999);
      for (final type in MilestoneType.values) {
        await service.markMilestoneShown(type);
      }
      await service.addListenSeconds(100 * 3600);

      final next = await service.getNextMilestone();
      expect(next.next, isNull);
      expect(next.remaining, 0);
    });

    test(
      'clamps remaining to zero when threshold is already exceeded',
      () async {
        final service = buildService(playCount: 150);
        final next = await service.getNextMilestone();
        expect(next.next, MilestoneType.songs100);
        expect(next.remaining, 0);
      },
    );
  });
}
