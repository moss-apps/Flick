import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/providers/tutorial_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late TutorialNotifier notifier;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    notifier = container.read(tutorialProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
    'core adapts to an empty or populated library without playing anything',
    () {
      notifier.start();
      notifier.beginCore(hasMusic: false);
      expect(container.read(tutorialProvider).step, TutorialStep.addMusic);
      notifier.onAction(TutorialAction.libraryReady);
      expect(container.read(tutorialProvider).step, TutorialStep.searchEntry);
      notifier.start();
      notifier.beginCore(hasMusic: true);
      expect(container.read(tutorialProvider).step, TutorialStep.searchEntry);
      expect(
        container.read(tutorialProvider).steps,
        isNot(contains(TutorialStep.addMusic)),
      );
    },
  );

  test(
    'only the relevant action advances; pauses and inactive sessions ignore actions',
    () {
      notifier.start();
      notifier.beginCore(hasMusic: true);
      notifier.onAction(TutorialAction.playerOpened);
      expect(container.read(tutorialProvider).step, TutorialStep.searchEntry);
      notifier.setPaused(true);
      notifier.onAction(TutorialAction.searchUsed);
      expect(container.read(tutorialProvider).step, TutorialStep.searchEntry);
      notifier.setPaused(false);
      notifier.onAction(TutorialAction.searchUsed);
      expect(container.read(tutorialProvider).step, TutorialStep.playSong);
      expect(container.read(tutorialProvider).actionConfirmed, isTrue);
      notifier.onAction(TutorialAction.searchUsed);
      expect(container.read(tutorialProvider).step, TutorialStep.playSong);
      notifier.previousStep();
      expect(container.read(tutorialProvider).actionConfirmed, isFalse);
    },
  );

  test(
    'continue always permits completion with no library, playback, or targets',
    () async {
      for (final guide in TutorialGuide.values) {
        notifier.start(guide: guide);
        final total = container.read(tutorialProvider).totalSteps;
        for (var i = 0; i < total; i++) {
          notifier.nextStep();
        }
        expect(container.read(tutorialProvider).active, isFalse);
        expect(
          container.read(tutorialProvider).progress[guide],
          TutorialProgress.completed,
        );
      }
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      for (final guide in TutorialGuide.values) {
        expect(prefs.getString('tutorial_v2_${guide.id}'), 'completed');
      }
    },
  );

  test(
    'dismissal is not completion, persists independently, and suppresses auto-start',
    () async {
      notifier.start();
      await notifier.skip();
      expect(container.read(tutorialProvider).completed, isFalse);
      expect(
        container.read(tutorialProvider).progress[TutorialGuide.core],
        TutorialProgress.dismissed,
      );
      notifier.flagAutoStart();
      expect(container.read(tutorialProvider).autoStartPending, isFalse);
      notifier.start(guide: TutorialGuide.audio);
      await notifier.complete();
      expect(container.read(tutorialProvider).completed, isFalse);
      expect(
        container.read(tutorialProvider).progress[TutorialGuide.audio],
        TutorialProgress.completed,
      );
      notifier.start(guide: TutorialGuide.audio);
      await notifier.skip();
      expect(
        container.read(tutorialProvider).progress[TutorialGuide.audio],
        TutorialProgress.completed,
      );
    },
  );

  test('closing the picker does not record completion or dismissal', () async {
    notifier.showPicker();
    await notifier.skip();
    expect(container.read(tutorialProvider).progress, isEmpty);
    expect(container.read(tutorialProvider).active, isFalse);
  });

  test(
    'legacy completion loads without rewinding an explicitly started guide',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_completed', true);
      container.dispose();
      container = ProviderContainer();
      notifier = container.read(tutorialProvider.notifier);
      notifier.flagAutoStart();
      notifier.start(guide: TutorialGuide.library);
      notifier.nextStep();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(tutorialProvider).completed, isTrue);
      expect(container.read(tutorialProvider).autoStartPending, isFalse);
      expect(container.read(tutorialProvider).guide, TutorialGuide.library);
      expect(
        container.read(tutorialProvider).step,
        TutorialStep.songCardGestures,
      );
    },
  );

  test(
    'guide and step IDs are unique and stable, and guidance stays out of core',
    () {
      expect(
        TutorialGuide.values.map((guide) => guide.id).toSet().length,
        TutorialGuide.values.length,
      );
      expect(
        TutorialStep.values.map((step) => step.id).toSet().length,
        TutorialStep.values.length,
      );
      expect(
        const TutorialState().steps,
        isNot(contains(TutorialStep.audioOutput)),
      );
      expect(
        const TutorialState().steps,
        isNot(contains(TutorialStep.sortButton)),
      );
    },
  );

  test('early replay dismissal cannot overwrite saved completion', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
    container.dispose();
    container = ProviderContainer();
    notifier = container.read(tutorialProvider.notifier);
    notifier.start();
    await notifier.skip();
    expect(container.read(tutorialProvider).completed, isTrue);
    expect(prefs.getString('tutorial_v2_core'), 'completed');

    container.dispose();
    container = ProviderContainer();
    notifier = container.read(tutorialProvider.notifier);
    notifier.start();
    await notifier.skip();
    expect(container.read(tutorialProvider).completed, isTrue);
    expect(prefs.getString('tutorial_v2_core'), 'completed');
  });
}
