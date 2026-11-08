import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/features/onboarding/tutorial_targets.dart';
import 'package:flick/l10n/l10n.dart';

enum TutorialGuide {
  core('core'),
  library('library'),
  player('player'),
  appearance('appearance'),
  audio('audio');

  const TutorialGuide(this.id);
  final String id;
  String title(AppLocalizations l10n) => switch (this) {
    core => l10n.tourCore,
    library => l10n.tourLibrary,
    player => l10n.tourPlayer,
    appearance => l10n.tourAppearance,
    audio => l10n.tourAudio,
  };
}

enum TutorialProgress { dismissed, completed }

enum TutorialAction {
  libraryReady,
  searchUsed,
  playbackStarted,
  playerOpened,
  sortOpened,
  songActionsOpened,
  queueOpened,
  lyricsOpened,
}

/// IDs, not enum ordinals, identify steps across releases.
enum TutorialStep {
  welcome('welcome'),
  addMusic('add_music', spotlightTarget: TutorialTarget.addMusicFolder),
  searchEntry(
    'find_music',
    spotlightTarget: TutorialTarget.songsSearchBar,
    requiredTabIndex: 1,
    action: TutorialAction.searchUsed,
  ),
  playSong(
    'play_song',
    spotlightTarget: TutorialTarget.songLibrary,
    requiredTabIndex: 1,
    action: TutorialAction.playbackStarted,
  ),
  miniPlayer(
    'mini_player',
    spotlightTarget: TutorialTarget.miniPlayer,
    action: TutorialAction.playerOpened,
  ),
  fullPlayerHint('full_player'),
  finish('finish'),
  sortButton(
    'sort',
    spotlightTarget: TutorialTarget.songsSortButton,
    requiredTabIndex: 1,
    action: TutorialAction.sortOpened,
  ),
  songCardGestures(
    'song_actions',
    spotlightTarget: TutorialTarget.songLibrary,
    requiredTabIndex: 1,
    action: TutorialAction.songActionsOpened,
  ),
  playlists('playlists'),
  queue(
    'queue',
    spotlightTarget: TutorialTarget.playerQueue,
    action: TutorialAction.queueOpened,
  ),
  lyrics(
    'lyrics',
    spotlightTarget: TutorialTarget.playerLyrics,
    action: TutorialAction.lyricsOpened,
  ),
  navBar('navigation', spotlightTarget: TutorialTarget.navBar),
  playerLayout('player_layout'),
  audioOutput('audio_output'),
  audioDsp('audio_dsp');

  const TutorialStep(
    this.id, {
    this.spotlightTarget,
    this.requiredTabIndex,
    this.action,
  });
  final String id;
  final TutorialTarget? spotlightTarget;
  final int? requiredTabIndex;
  final TutorialAction? action;
  String title(AppLocalizations l10n) => switch (this) {
    welcome => l10n.tourWelcomeTitle,
    addMusic => l10n.addMusicFolder,
    searchEntry => l10n.search,
    playSong => l10n.tourPlayTitle,
    miniPlayer => l10n.miniPlayer,
    fullPlayerHint => l10n.fullPlayer,
    finish => l10n.tourFinishTitle,
    sortButton => l10n.sortFilter,
    songCardGestures => l10n.songGestures,
    playlists => l10n.playlists,
    queue => l10n.queue,
    lyrics => l10n.lyrics,
    navBar => l10n.navigationBar,
    playerLayout => l10n.tourPlayerLayoutTitle,
    audioOutput => l10n.tourOutputTitle,
    audioDsp => l10n.tourDspTitle,
  };
  String description(AppLocalizations l10n) => switch (this) {
    welcome => l10n.tourWelcomeBody,
    addMusic => l10n.tourAddBody,
    searchEntry => l10n.tourSearchBody,
    playSong => l10n.tourPlayBody,
    miniPlayer => l10n.tourMiniBody,
    fullPlayerHint => l10n.tourFullBody,
    finish => l10n.tourFinishBody,
    sortButton => l10n.tourSortBody,
    songCardGestures => l10n.tourActionsBody,
    playlists => l10n.tourPlaylistsBody,
    queue => l10n.tourQueueBody,
    lyrics => l10n.tourLyricsBody,
    navBar => l10n.tourNavBody,
    playerLayout => l10n.tourLayoutBody,
    audioOutput => l10n.tourOutputBody,
    audioDsp => l10n.tourDspBody,
  };
  String? get manualSection => switch (this) {
    searchEntry => 'search',
    sortButton || songCardGestures || playSong => 'songs',
    addMusic => 'folders',
    playlists => 'playlists',
    miniPlayer => 'mini_player',
    fullPlayerHint => 'full_player',
    queue => 'queue',
    lyrics => 'lyrics',
    audioDsp => 'equalizer',
    navBar || playerLayout || audioOutput => 'settings',
    _ => null,
  };
}

List<TutorialStep> _steps(TutorialGuide guide, bool includeAddMusic) =>
    switch (guide) {
      TutorialGuide.core => [
        TutorialStep.welcome,
        if (includeAddMusic) TutorialStep.addMusic,
        TutorialStep.searchEntry,
        TutorialStep.playSong,
        TutorialStep.miniPlayer,
        TutorialStep.fullPlayerHint,
        TutorialStep.finish,
      ],
      TutorialGuide.library => const [
        TutorialStep.sortButton,
        TutorialStep.songCardGestures,
        TutorialStep.playlists,
        TutorialStep.finish,
      ],
      TutorialGuide.player => const [
        TutorialStep.miniPlayer,
        TutorialStep.queue,
        TutorialStep.lyrics,
        TutorialStep.finish,
      ],
      TutorialGuide.appearance => const [
        TutorialStep.navBar,
        TutorialStep.playerLayout,
        TutorialStep.finish,
      ],
      TutorialGuide.audio => const [
        TutorialStep.audioOutput,
        TutorialStep.audioDsp,
        TutorialStep.finish,
      ],
    };

class TutorialState {
  const TutorialState({
    this.active = false,
    this.currentStep = 0,
    this.completed = false,
    this.autoStartPending = false,
    this.guide = TutorialGuide.core,
    this.picker = false,
    this.includeAddMusic = true,
    this.actionConfirmed = false,
    this.paused = false,
    this.progress = const {},
  });
  final bool active;
  final int currentStep;
  final bool completed;
  final bool autoStartPending;
  final TutorialGuide guide;
  final bool picker;
  final bool includeAddMusic;
  final bool actionConfirmed;
  final bool paused;
  final Map<TutorialGuide, TutorialProgress> progress;
  List<TutorialStep> get steps => _steps(guide, includeAddMusic);
  TutorialStep get step => steps[currentStep.clamp(0, steps.length - 1)];
  bool get isLastStep => currentStep >= steps.length - 1;
  int get totalSteps => steps.length;
  TutorialState copyWith({
    bool? active,
    int? currentStep,
    bool? completed,
    bool? autoStartPending,
    TutorialGuide? guide,
    bool? picker,
    bool? includeAddMusic,
    bool? actionConfirmed,
    bool? paused,
    Map<TutorialGuide, TutorialProgress>? progress,
  }) => TutorialState(
    active: active ?? this.active,
    currentStep: currentStep ?? this.currentStep,
    completed: completed ?? this.completed,
    autoStartPending: autoStartPending ?? this.autoStartPending,
    guide: guide ?? this.guide,
    picker: picker ?? this.picker,
    includeAddMusic: includeAddMusic ?? this.includeAddMusic,
    actionConfirmed: actionConfirmed ?? this.actionConfirmed,
    paused: paused ?? this.paused,
    progress: progress ?? this.progress,
  );
}

class TutorialNotifier extends Notifier<TutorialState> {
  @override
  TutorialState build() {
    Future.microtask(_loadPreference);
    return const TutorialState();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final progress = <TutorialGuide, TutorialProgress>{};
    for (final guide in TutorialGuide.values) {
      final saved = prefs.getString('tutorial_v2_${guide.id}');
      for (final value in TutorialProgress.values) {
        if (saved == value.name) progress[guide] = value;
      }
    }
    if (!progress.containsKey(TutorialGuide.core) &&
        (prefs.getBool('tutorial_completed') ?? false)) {
      progress[TutorialGuide.core] = TutorialProgress.completed;
    }
    // A slow preference read must not rewind a guide already started by the user.
    for (final entry in state.progress.entries) {
      if (progress[entry.key] != TutorialProgress.completed) {
        progress[entry.key] = entry.value;
      }
    }
    state = state.copyWith(
      progress: progress,
      completed: progress[TutorialGuide.core] == TutorialProgress.completed,
      autoStartPending:
          state.autoStartPending && !progress.containsKey(TutorialGuide.core),
    );
  }

  void flagAutoStart() {
    if (state.progress.containsKey(TutorialGuide.core)) return;
    state = state.copyWith(autoStartPending: true);
  }

  void start({TutorialGuide guide = TutorialGuide.core}) {
    state = state.copyWith(
      active: true,
      guide: guide,
      currentStep: 0,
      picker: false,
      autoStartPending: false,
      actionConfirmed: false,
      paused: false,
      includeAddMusic: true,
    );
  }

  void showPicker() => state = state.copyWith(
    active: true,
    picker: true,
    autoStartPending: false,
    paused: false,
  );
  void beginCore({required bool hasMusic}) {
    if (!state.active || state.step != TutorialStep.welcome) return;
    state = state.copyWith(
      includeAddMusic: !hasMusic,
      currentStep: 1,
      actionConfirmed: false,
    );
  }

  void nextStep() {
    if (!state.active || state.picker) return;
    if (state.isLastStep) {
      complete();
    } else {
      state = state.copyWith(
        currentStep: state.currentStep + 1,
        actionConfirmed: false,
      );
    }
  }

  void previousStep() {
    if (state.active && state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        actionConfirmed: false,
      );
    }
  }

  void onAction(TutorialAction action) {
    if (!state.active || state.picker || state.paused) return;
    final expected = state.step == TutorialStep.addMusic
        ? TutorialAction.libraryReady
        : state.step.action;
    if (expected != action) return;
    nextStep();
    state = state.copyWith(actionConfirmed: true);
  }

  void setPaused(bool paused) {
    if (ref.mounted) state = state.copyWith(paused: paused);
  }

  Future<void> skip() async {
    if (!state.active) return;
    if (state.picker) {
      state = state.copyWith(active: false, picker: false);
      return;
    }
    await _finish(TutorialProgress.dismissed);
  }

  Future<void> complete() => _finish(TutorialProgress.completed);
  Future<void> _finish(TutorialProgress result) async {
    final guide = state.guide;
    final progress = {...state.progress};
    // Replaying and dismissing a completed guide never downgrades its status.
    if (progress[guide] != TutorialProgress.completed) progress[guide] = result;
    state = state.copyWith(
      active: false,
      picker: false,
      autoStartPending: false,
      paused: false,
      progress: progress,
      completed: progress[TutorialGuide.core] == TutorialProgress.completed,
    );
    final prefs = await SharedPreferences.getInstance();
    final key = 'tutorial_v2_${guide.id}';
    final saved = prefs.getString(key);
    final wasCompleted =
        saved == TutorialProgress.completed.name ||
        (saved == null &&
            guide == TutorialGuide.core &&
            (prefs.getBool('tutorial_completed') ?? false));
    final status =
        wasCompleted ||
            (ref.mounted && state.progress[guide] == TutorialProgress.completed)
        ? TutorialProgress.completed
        : progress[guide]!;
    if (ref.mounted && state.progress[guide] != status) {
      final latest = {...state.progress, guide: status};
      state = state.copyWith(
        progress: latest,
        completed: latest[TutorialGuide.core] == TutorialProgress.completed,
      );
    }
    await prefs.setString(key, status.name);
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialState>(
  TutorialNotifier.new,
);
