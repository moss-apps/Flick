import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/navigation/root_navigator.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/features/manual/screens/manual_screen.dart';
import 'package:flick/features/onboarding/tutorial_navigation.dart';
import 'package:flick/features/onboarding/tutorial_targets.dart';
import 'package:flick/features/settings/screens/library_settings_screen.dart';
import 'package:flick/features/settings/screens/bottom_bar_settings_screen.dart';
import 'package:flick/features/settings/screens/player_layout_settings_screen.dart';
import 'package:flick/features/settings/screens/audio_settings_screen.dart';
import 'package:flick/features/settings/screens/equalizer_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/providers/nav_bar_config_provider.dart';
import 'package:flick/providers/navigation_provider.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flick/providers/tutorial_provider.dart';

/// Above both navigators, but never above a modal or an unrelated destination.
class TutorialHost extends ConsumerStatefulWidget {
  const TutorialHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends ConsumerState<TutorialHost>
    with WidgetsBindingObserver {
  bool _resumed = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tutorialNavigation.addListener(_routeChanged);
  }

  @override
  void dispose() {
    tutorialNavigation.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _resumed = state == AppLifecycleState.resumed);
  }

  void _routeChanged() {
    if (!mounted) return;
    final name = tutorialNavigation.currentName;
    if (tutorialNavigation.visible) {
      if (name == '/full_player') {
        ref
            .read(tutorialProvider.notifier)
            .onAction(TutorialAction.playerOpened);
      }
      if (name == '/queue') {
        ref
            .read(tutorialProvider.notifier)
            .onAction(TutorialAction.queueOpened);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorialProvider);
    if (state.active) {
      ref.listen(isPlayingProvider, (previous, next) {
        if (_resumed &&
            tutorialNavigation.visible &&
            previous == false &&
            next) {
          ref
              .read(tutorialProvider.notifier)
              .onAction(TutorialAction.playbackStarted);
        }
      });
      if (state.step == TutorialStep.addMusic) {
        ref.listen(songsProvider, (previous, next) {
          if (next.value?.songs.isNotEmpty ?? false) {
            ref
                .read(tutorialProvider.notifier)
                .onAction(TutorialAction.libraryReady);
          }
        });
      }
    }
    final inQueue = tutorialNavigation.currentName == '/queue';
    return Stack(
      children: [
        widget.child,
        if (_resumed &&
            tutorialNavigation.visible &&
            (!inQueue || state.step == TutorialStep.queue || state.picker))
          const Positioned.fill(child: TutorialOverlay()),
      ],
    );
  }
}

/// No gesture barrier: the spotlight and the rest of the real app remain usable.
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});
  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with WidgetsBindingObserver {
  static const _accent = Color(0xFFE3F369);
  final _overlayKey = GlobalKey();
  late final TutorialTargetRegistry _registry;
  late final ProviderSubscription<TutorialState> _subscription;
  Rect? _spotlight;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registry = ref.read(tutorialTargetRegistryProvider)..addListener(_measure);
    _subscription = ref.listenManual(tutorialProvider, (previous, next) {
      if (previous?.step != next.step ||
          previous?.active != next.active ||
          previous?.picker != next.picker ||
          previous?.guide != next.guide) {
        _scheduleActivation();
      }
    });
    _scheduleActivation();
  }

  @override
  void dispose() {
    _subscription.close();
    _registry.removeListener(_measure);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _registry.changed();
  void _scheduleActivation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(tutorialProvider);
      if (state.active && !state.picker) {
        if (state.step == TutorialStep.miniPlayer &&
            tutorialNavigation.currentName == '/full_player') {
          ref
              .read(tutorialProvider.notifier)
              .onAction(TutorialAction.playerOpened);
          return;
        }
        if (state.step == TutorialStep.searchEntry &&
            tutorialNavigation.root.top?.settings.name == '/tutorial/library') {
          _navigator.pop();
        }
        var tab = state.step.requiredTabIndex;
        final dedicatedSearch = ref
            .read(navBarConfigProvider)
            .orderedButtons
            .contains(NavBarButton.search);
        if ((state.step == TutorialStep.searchEntry && dedicatedSearch) ||
            (state.step == TutorialStep.playSong &&
                ref.read(navigationIndexProvider) ==
                    NavBarButton.search.pageIndex)) {
          tab = NavBarButton.search.pageIndex;
        }
        if (tab != null && tutorialNavigation.root.top?.isFirst != false) {
          ref.read(navigationIndexProvider.notifier).setIndex(tab);
        }
      }
      _measure();
    });
  }

  void _measure() {
    if (!mounted) return;
    final target = ref.read(tutorialProvider).step.spotlightTarget;
    final object = _overlayKey.currentContext?.findRenderObject();
    Rect? rect;
    if (object is RenderBox && object.hasSize && target != null) {
      rect = _registry.rectFor(target, relativeTo: object);
      final viewport = Offset.zero & object.size;
      if (rect != null) rect = rect.intersect(viewport);
      if (rect?.isEmpty ?? false) rect = null;
    }
    if (_spotlight != rect) setState(() => _spotlight = rect);
  }

  NavigatorState get _navigator =>
      rootNavigatorKey.currentState ?? Navigator.of(context);
  Future<void> _openPage(Widget page, String name) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/tutorial/$name'),
        builder: (_) => _GuidePage(child: page),
      ),
    );
    if (mounted) _scheduleActivation();
  }

  Future<void> _manual(String? section) async {
    final notifier = ref.read(tutorialProvider.notifier);
    notifier.setPaused(true);
    await _navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ManualScreen(initialSection: section),
      ),
    );
    // The route-aware host unmounts this overlay while the manual is open.
    notifier.setPaused(false);
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();
    final state = ref.read(tutorialProvider);
    if (state.step == TutorialStep.welcome) {
      ref
          .read(tutorialProvider.notifier)
          .beginCore(
            hasMusic: ref.read(songsProvider).value?.songs.isNotEmpty ?? false,
          );
    } else {
      // Leave only guide-owned destinations; never pop a route the listener opened.
      if (tutorialNavigation.root.top?.settings.name?.startsWith(
            '/tutorial/',
          ) ??
          false) {
        _navigator.pop();
      }
      ref.read(tutorialProvider.notifier).nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorialProvider);
    if (!state.active || state.paused) return const SizedBox.shrink();
    final l10n = context.l10n.englishForFilipino;
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final availableHeight = math.max(
          0.0,
          constraints.maxHeight -
              media.padding.top -
              math.max(media.viewInsets.bottom, media.padding.bottom) -
              24,
        );
        final centered =
            state.picker ||
            state.step == TutorialStep.welcome ||
            state.isLastStep;
        final above =
            !centered &&
            _spotlight != null &&
            _spotlight!.center.dy > constraints.maxHeight / 2;
        return Stack(
          key: _overlayKey,
          children: [
            if (!centered && _spotlight != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(painter: _SpotlightPainter(_spotlight!)),
                  ),
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  media.padding.left + 12,
                  media.padding.top + 12,
                  media.padding.right + 12,
                  math.max(media.viewInsets.bottom, media.padding.bottom) + 12,
                ),
                child: Align(
                  alignment: centered
                      ? Alignment.center
                      : above
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 440,
                      maxHeight: centered
                          ? availableHeight
                          : math.min(
                              availableHeight,
                              math.max(180, availableHeight * .48),
                            ),
                    ),
                    child: Material(
                      color: const Color(0xFF20211E),
                      borderRadius: BorderRadius.circular(16),
                      elevation: 8,
                      shadowColor: Colors.black54,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: state.picker
                            ? _picker(state, l10n)
                            : _tooltip(state, l10n),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  ButtonStyle get _textStyle => TextButton.styleFrom(
    foregroundColor: const Color(0xFFF1F0EB),
    minimumSize: const Size(48, 48),
  );

  void _selectGuide(TutorialGuide guide) {
    final name = tutorialNavigation.currentName;
    // Choosing a library/appearance guide from the player's finish screen is
    // an explicit request to return to the shell, not an automatic route pop.
    if (guide != TutorialGuide.player &&
        (name == '/full_player' || name == '/queue')) {
      tutorialNavigation.root.navigator?.popUntil((route) => route.isFirst);
      tutorialNavigation.nested.navigator?.popUntil((route) => route.isFirst);
    }
    ref.read(tutorialProvider.notifier).start(guide: guide);
  }

  Widget _picker(TutorialState state, AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.tourGuides,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => ref.read(tutorialProvider.notifier).skip(),
            icon: Icon(Icons.close, semanticLabel: l10n.close),
          ),
        ],
      ),
      Text(
        l10n.tourPickerBody,
        style: const TextStyle(
          color: Color(0xFFD3D5CC),
          fontSize: 15,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 16),
      for (final guide in TutorialGuide.values)
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 12,
          title: Text(guide.title(l10n)),
          trailing: Icon(
            state.progress[guide] == TutorialProgress.completed
                ? Icons.check_circle_outline
                : Icons.arrow_forward,
            color: _accent,
          ),
          onTap: () => _selectGuide(guide),
        ),
    ],
  );
  Widget _tooltip(TutorialState state, AppLocalizations l10n) {
    final step = state.step;
    final welcome = step == TutorialStep.welcome;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${state.currentStep + 1} / ${state.totalSteps}',
                style: const TextStyle(color: Color(0xFFD3D5CC), fontSize: 13),
              ),
            ),
            TextButton(
              style: _textStyle,
              onPressed: () => ref.read(tutorialProvider.notifier).skip(),
              child: Text(welcome ? l10n.tourNotNow : l10n.tourEnd),
            ),
          ],
        ),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            step.title(l10n),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF1F0EB),
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          step.description(l10n),
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: Color(0xFFD3D5CC),
          ),
        ),
        if (state.actionConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              liveRegion: true,
              child: Text(
                l10n.tourActionConfirmed,
                style: const TextStyle(color: _accent, fontSize: 14),
              ),
            ),
          ),
        if (_spotlight == null && step.spotlightTarget != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l10n.tourUnavailable,
              style: const TextStyle(
                color: Color(0xFFD3D5CC),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ..._stepActions(state, l10n),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            if (state.currentStep > 0)
              TextButton(
                style: _textStyle,
                onPressed: () =>
                    ref.read(tutorialProvider.notifier).previousStep(),
                child: Text(l10n.back),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: const Color(0xFF151610),
                minimumSize: const Size(112, 48),
              ),
              onPressed: _continue,
              child: Text(
                welcome
                    ? l10n.tourStart
                    : state.isLastStep
                    ? l10n.done
                    : l10n.tourContinue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _stepActions(TutorialState state, AppLocalizations l10n) {
    final step = state.step;
    Widget action(String label, VoidCallback callback) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: _textStyle,
        onPressed: callback,
        child: Text(label),
      ),
    );
    final song = ref.watch(currentSongProvider);
    return [
      if (step == TutorialStep.addMusic &&
          tutorialNavigation.root.top?.settings.name != '/tutorial/library')
        action(
          l10n.addMusicFolder,
          () => _openPage(
            const LibrarySettingsScreen(initialSection: 'libraryLabel'),
            'library',
          ),
        ),
      if (step == TutorialStep.playSong && song != null)
        action(
          l10n.tourUseCurrent,
          () => ref.read(tutorialProvider.notifier).nextStep(),
        ),
      if ((step == TutorialStep.miniPlayer ||
              step == TutorialStep.fullPlayerHint ||
              step == TutorialStep.queue ||
              step == TutorialStep.lyrics) &&
          song != null &&
          tutorialNavigation.root.top?.settings.name != '/full_player')
        action(
          l10n.openPlayer,
          () => NavigationHelper.navigateToFullPlayer(
            _navigator.context,
            heroTag: 'tutorial_player_art',
          ),
        ),
      if (step == TutorialStep.navBar)
        action(
          l10n.tourOpenNavigation,
          () => _openPage(const BottomBarSettingsScreen(), 'navigation'),
        ),
      if (step == TutorialStep.playerLayout)
        action(
          l10n.tourOpenLayout,
          () => _openPage(const PlayerLayoutSettingsScreen(), 'layout'),
        ),
      if (step == TutorialStep.audioOutput)
        action(
          l10n.tourOpenAudio,
          () => _openPage(const AudioSettingsScreen(), 'audio'),
        ),
      if (step == TutorialStep.audioDsp)
        action(
          l10n.equalizer,
          () => _openPage(const EqualizerScreen(), 'equalizer'),
        ),
      if (step.manualSection != null)
        action(l10n.tourReadMore, () => _manual(step.manualSection)),
      if (state.isLastStep) ...[
        action(l10n.tourGuides, () async {
          await ref.read(tutorialProvider.notifier).complete();
          if (mounted) ref.read(tutorialProvider.notifier).showPicker();
        }),
        action(l10n.openManual, () => _manual(null)),
      ],
    ];
  }
}

class _GuidePage extends ConsumerWidget {
  const _GuidePage({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    canPop: !ref.watch(tutorialProvider).active,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) ref.read(tutorialProvider.notifier).skip();
    },
    child: child,
  );
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.rect);
  final Rect rect;
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      rect.inflate(3),
      const Radius.circular(12),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .32));
    canvas.drawRRect(
      hole,
      Paint()
        ..color = const Color(0xFFE3F369)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.rect != rect;
}
