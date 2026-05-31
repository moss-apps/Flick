import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TutorialStep {
  welcome,
  navBar,
  miniPlayer,
  browseMusic,
  settingsTab,
  fullPlayer,
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

  TutorialStep get step => TutorialStep.values[
      currentStep.clamp(0, TutorialStep.values.length - 1)];
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

final tutorialProvider =
    NotifierProvider<TutorialNotifier, TutorialState>(
  TutorialNotifier.new,
);
