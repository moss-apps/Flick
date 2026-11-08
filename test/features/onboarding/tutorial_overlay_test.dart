import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/onboarding/tutorial_navigation.dart';
import 'package:flick/features/onboarding/tutorial_targets.dart';
import 'package:flick/features/onboarding/widgets/tutorial_overlay.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flick/providers/tutorial_provider.dart';

class _Playback extends Notifier<bool> {
  @override
  bool build() => false;
  void play() => state = true;
}

final _playback = NotifierProvider<_Playback, bool>(_Playback.new);

class _EmptySongs extends SongsNotifier {
  @override
  Future<SongsState> build() async => SongsState();
}

Widget _host(
  Widget child, {
  double scale = 1,
  List<NavigatorObserver> observers = const [],
  Locale locale = const Locale('en'),
  double keyboardInset = 0,
  bool globalHost = false,
}) => ProviderScope(
  overrides: [
    currentSongProvider.overrideWithValue(null),
    isPlayingProvider.overrideWith((ref) => ref.watch(_playback)),
    songsProvider.overrideWith(_EmptySongs.new),
  ],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    navigatorObservers: observers,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
      ),
      child: globalHost ? TutorialHost(child: child!) : child!,
    ),
    home: Scaffold(body: child),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'highlighted real control receives taps and only its action advances',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: TutorialTargetAnchor(
                  target: TutorialTarget.songsSearchBar,
                  child: Consumer(
                    builder: (context, ref, _) => TextButton(
                      onPressed: () {
                        taps++;
                        ref
                            .read(tutorialProvider.notifier)
                            .onAction(TutorialAction.searchUsed);
                      },
                      child: const Text('Real search'),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: TutorialOverlay()),
            ],
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TutorialOverlay)),
      );
      container.read(tutorialProvider.notifier)
        ..start()
        ..beginCore(hasMusic: true);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Real search'));
      await tester.pump();
      expect(taps, 1);
      expect(container.read(tutorialProvider).step, TutorialStep.playSong);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing controls remain skippable at large text and landscape sizes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_host(const TutorialOverlay(), scale: 2));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TutorialOverlay)),
      );
      container
          .read(tutorialProvider.notifier)
          .start(guide: TutorialGuide.player);
      await tester.pump();
      await tester.pump();
      final copy = lookupFlickLocalizations(const Locale('en'));
      expect(find.text(copy.tourUnavailable), findsOneWidget);
      await tester.ensureVisible(find.text(copy.tourContinue));
      await tester.tap(find.text(copy.tourContinue));
      await tester.pump();
      expect(container.read(tutorialProvider).step, TutorialStep.queue);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registry preserves earlier owners and rejects zero-size targets',
    (tester) async {
      final first = GlobalKey();
      final second = GlobalKey();
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              SizedBox(key: first, width: 60, height: 40),
              SizedBox(key: second, width: 0, height: 0),
            ],
          ),
        ),
      );
      final registry = TutorialTargetRegistry();
      addTearDown(registry.dispose);
      registry.register(TutorialTarget.miniPlayer, first);
      registry.register(TutorialTarget.miniPlayer, second);
      expect(
        registry.rectFor(TutorialTarget.miniPlayer)?.size,
        const Size(60, 40),
      );
      registry.unregister(TutorialTarget.miniPlayer, second);
      expect(
        registry.rectFor(TutorialTarget.miniPlayer)?.size,
        const Size(60, 40),
      );
      registry.unregister(TutorialTarget.miniPlayer, first);
      expect(registry.rectFor(TutorialTarget.miniPlayer), isNull);
      await tester.pump();
    },
  );

  testWidgets(
    'navigation allows player routes but yields to modal and unrelated pages',
    (tester) async {
      final navigation = TutorialNavigation();
      addTearDown(navigation.dispose);
      await tester.pumpWidget(
        _host(const SizedBox(), observers: [navigation.root]),
      );
      await tester.pump();
      expect(navigation.visible, isTrue);
      final context = tester.element(find.byType(Scaffold));
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/full_player'),
          builder: (_) => const Scaffold(),
        ),
      );
      await tester.pumpAndSettle();
      expect(navigation.visible, isTrue);
      expect(navigation.currentName, '/full_player');
      showDialog<void>(context: context, builder: (_) => const AlertDialog());
      await tester.pumpAndSettle();
      expect(navigation.visible, isFalse);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(navigation.visible, isTrue);
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pumpAndSettle();
      expect(navigation.visible, isFalse);
    },
  );

  testWidgets(
    'global host follows playback and player, and yields to dialogs',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(),
          globalHost: true,
          observers: [tutorialNavigation.root],
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(Scaffold));
      final container = ProviderScope.containerOf(context);
      container.read(tutorialProvider.notifier)
        ..start()
        ..beginCore(hasMusic: true)
        ..nextStep();
      await tester.pump();
      container.read(_playback.notifier).play();
      await tester.pump();
      expect(container.read(tutorialProvider).step, TutorialStep.miniPlayer);
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/full_player'),
          builder: (_) => const Scaffold(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(tutorialProvider).step,
        TutorialStep.fullPlayerHint,
      );
      final copy = lookupFlickLocalizations(const Locale('en'));
      expect(find.text(copy.tourFullBody), findsOneWidget);
      showDialog<void>(context: context, builder: (_) => const AlertDialog());
      await tester.pumpAndSettle();
      expect(find.byType(TutorialOverlay), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text(copy.tourFullBody), findsOneWidget);
      container.read(tutorialProvider.notifier).showPicker();
      await tester.pump();
      await tester.tap(find.text(copy.tourLibrary));
      await tester.pumpAndSettle();
      expect(tutorialNavigation.root.top?.isFirst, isTrue);
      expect(container.read(tutorialProvider).step, TutorialStep.sortButton);
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialOverlay), findsNothing);
    },
  );

  testWidgets(
    'Chinese large text keeps keyboard-safe, labeled native actions',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const TutorialOverlay(),
          locale: const Locale('zh'),
          scale: 2,
          keyboardInset: 300,
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TutorialOverlay)),
      );
      container.read(tutorialProvider.notifier)
        ..start()
        ..beginCore(hasMusic: true);
      await tester.pump();
      await tester.pump();
      final copy = lookupFlickLocalizations(const Locale('zh'));
      expect(find.text(copy.tourSearchBody), findsOneWidget);
      final button = find.widgetWithText(FilledButton, copy.tourContinue);
      await tester.ensureVisible(button);
      expect(tester.getSemantics(button).label, contains(copy.tourContinue));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(500));
      await tester.tap(button);
      await tester.pump();
      expect(container.read(tutorialProvider).step, TutorialStep.playSong);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
