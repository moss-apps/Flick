import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/features/onboarding/tutorial_targets.dart';

enum TutorialStep {
  welcome(
    title: 'Welcome to Flick',
    description: "Let's take a quick tour of your new music player.",
  ),
  navBar(
    title: 'Navigation Bar',
    description: 'Tap icons to switch tabs. Long-press to customize the bar.',
    spotlightTarget: TutorialTarget.navBar,
  ),
  songsTab(
    title: 'Songs Tab',
    description: 'Your whole library lives here. Tap any song to play it.',
    requiredTabIndex: 1,
  ),
  searchEntry(
    title: 'Search',
    description: 'Search across songs, artists, and albums instantly.',
    spotlightTarget: TutorialTarget.songsSearchBar,
    requiredTabIndex: 1,
  ),
  sortButton(
    title: 'Sort & Filter',
    description: 'Reorder, filter, and shuffle from this header.',
    spotlightTarget: TutorialTarget.songsSortButton,
    requiredTabIndex: 1,
  ),
  songCardGestures(
    title: 'Song Gestures',
    description: 'Tap to play, long-press for options (queue, play next, info).',
    requiredTabIndex: 1,
  ),
  miniPlayer(
    title: 'Mini Player',
    description: "Shows what's playing. Tap to open the full player.",
    spotlightTarget: TutorialTarget.miniPlayer,
  ),
  settingsTab(
    title: 'Settings',
    description: 'Customize audio, display, navigation, and integrations.',
    requiredTabIndex: 2,
  ),
  fullPlayerHint(
    title: 'Full Player',
    description:
        'Tap the mini player for waveform seekbar, EQ, lyrics, and visualizer.',
  ),
  manualPointer(
    title: "That's the tour!",
    description:
        'Want every control documented? Open the in-app Manual anytime from Settings \u2192 Help & Manual.',
    isManualPointer: true,
  );

  const TutorialStep({
    required this.title,
    required this.description,
    this.spotlightTarget,
    this.requiredTabIndex,
    this.isManualPointer = false,
  });

  final String title;
  final String description;
  final TutorialTarget? spotlightTarget;
  final int? requiredTabIndex;
  final bool isManualPointer;
}

class TutorialState {
  final bool active;
  final int currentStep;
  final bool completed;
  final bool autoStartPending;

  const TutorialState({
    this.active = false,
    this.currentStep = 0,
    this.completed = false,
    this.autoStartPending = false,
  });

  TutorialState copyWith({
    bool? active,
    int? currentStep,
    bool? completed,
    bool? autoStartPending,
  }) {
    return TutorialState(
      active: active ?? this.active,
      currentStep: currentStep ?? this.currentStep,
      completed: completed ?? this.completed,
      autoStartPending: autoStartPending ?? this.autoStartPending,
    );
  }

  TutorialStep get step =>
      TutorialStep.values[currentStep.clamp(0, TutorialStep.values.length - 1)];
  bool get isLastStep => currentStep >= TutorialStep.values.length - 1;
  int get totalSteps => TutorialStep.values.length;
}

class TutorialNotifier extends Notifier<TutorialState> {
  static const _prefKey = 'tutorial_completed';
  bool _initialized = false;

  @override
  TutorialState build() {
    if (!_initialized) {
      _initialized = true;
      Future.microtask(_loadPreference);
    }
    return const TutorialState();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_prefKey) ?? false;
    if (!ref.mounted) return;
    state = state.copyWith(completed: completed);
  }

  void flagAutoStart() {
    state = const TutorialState(autoStartPending: true, completed: false);
  }

  void start() {
    state = const TutorialState(active: true, currentStep: 0);
  }

  void nextStep() {
    if (state.currentStep < TutorialStep.values.length - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    } else {
      complete();
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void skip() {
    complete();
  }

  Future<void> complete() async {
    state = const TutorialState(active: false, completed: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialState>(
  TutorialNotifier.new,
);
