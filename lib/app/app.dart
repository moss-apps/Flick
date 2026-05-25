import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/features/songs/screens/songs_screen.dart';
import 'package:flick/features/menu/screens/menu_screen.dart';
import 'package:flick/features/settings/screens/settings_screen.dart';
import 'package:flick/features/albums/screens/albums_screen.dart';
import 'package:flick/features/artists/screens/artists_screen.dart';
import 'package:flick/features/folders/screens/folders_screen.dart';
import 'package:flick/features/playlists/screens/playlists_screen.dart';
import 'package:flick/features/favorites/screens/favorites_screen.dart';
import 'package:flick/features/search/screens/search_screen.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/widgets/navigation/flick_nav_bar.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/onboarding/screens/onboarding_screen.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/library_scanner_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/widget_sync_service.dart';
import 'package:flick/services/widget_intent_handler.dart';
import 'package:flick/models/nav_bar_config.dart';

/// Main application widget for Flick Player.
class FlickPlayerApp extends StatelessWidget {
  const FlickPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style for immersive experience
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'Flick Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _RootRouter(),
    );
  }
}

/// Main shell widget that contains navigation and screens.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Animation controller for smoother nav bar transitions
  late final AnimationController _navBarAnimationController;
  late final Animation<Offset> _navBarSlideAnimation;
  late final PageController _pageController;
  late final ProviderSubscription<bool> _navBarVisibilitySubscription;
  late final ProviderSubscription<bool> _navBarAlwaysVisibleSubscription;
  late final ProviderSubscription<Song?> _currentSongSubscription;
  late final ProviderSubscription<int> _navigationIndexSubscription;
  late final ProviderSubscription<PlayerState> _widgetSyncSubscription;
  late final WidgetIntentHandler _widgetIntentHandler;

  // Track previous song to detect changes
  Song? _previousSong;
  // Track the PageView position being animated to programmatically.
  // When non-null, onPageChanged will allow navigation to this position
  // even if it's beyond enabledCount (disabled essential pages).
  // Cleared once the target position is reached.
  int? _programmaticPageTarget;
  late final PlayerService _playerService;

  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Seed _previousSong from the already-restored state so the auto-navigate
    // listener doesn't treat the restored song as "new" on cold start.
    _previousSong = ref.read(currentSongProvider);
    _playerService = ref.read(playerServiceProvider);
    ref.read(updateCheckProvider.notifier);
    final initialConfig = ref.read(navBarConfigProvider);
    final defaultPage =
        initialConfig.orderedButtons.contains(NavBarButton.songs)
        ? NavBarButton.songs.pageIndex
        : NavBarButton.menu.pageIndex;
    ref.read(navigationIndexProvider.notifier).setIndex(defaultPage);
    final initialIndex = ref.read(navigationIndexProvider);
    final initialOrder = _getPageOrder(initialConfig);
    final initialPosition = initialOrder.indexWhere(
      (b) => b.pageIndex == initialIndex,
    );
    _pageController = PageController(
      initialPage: initialPosition >= 0 ? initialPosition : 0,
    );
    _navBarAnimationController = AnimationController(
      vsync: this,
      duration: AppConstants.animationNormal,
    );
    _navBarSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1.15)).animate(
          CurvedAnimation(
            parent: _navBarAnimationController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeOutCubic,
          ),
        );

    // Home-screen widget integration: keep widgets in sync with player and
    // route widget click intents back into the app.
    _widgetSyncSubscription = installWidgetSync(ref);
    _widgetIntentHandler = WidgetIntentHandler(
      ref,
      onOpenQueue: () => NavigationHelper.navigateToQueue(context),
    );
    unawaited(_widgetIntentHandler.attach());

    _navBarVisibilitySubscription = ref.listenManual<bool>(
      navBarVisibleProvider,
      (previous, next) {
        _onNavBarVisibilityChanged(next);
      },
    );

    _navBarAlwaysVisibleSubscription = ref.listenManual<bool>(
      navBarAlwaysVisibleProvider,
      (previous, next) {
        if (next) {
          ref.read(navBarVisibleProvider.notifier).setVisible(true);
        }
      },
    );

    _currentSongSubscription = ref.listenManual<Song?>(currentSongProvider, (
      previousSong,
      nextSong,
    ) {
      // Only auto-navigate to the full player when a *different* song starts
      // playing while the player is active. A cold-start restore always starts
      // in a paused state, so we check isPlaying to avoid popping the full
      // player screen on every app launch.
      final songChanged =
          nextSong != null &&
          _previousSong != null &&
          _previousSong!.id != nextSong.id;

      if (!songChanged && nextSong?.isExternal == true) {
        _maybeOpenExternalPlayer(nextSong);
      }

      _previousSong = nextSong;
    });

    ref.listenManual<NavBarConfig>(navBarConfigProvider, (previous, next) {
      if (previous == null || !mounted) return;
      final currentPageIndex = ref.read(navigationIndexProvider);
      final oldOrder = _getPageOrder(previous);
      final newOrder = _getPageOrder(next);
      final oldPosition = oldOrder.indexWhere(
        (b) => b.pageIndex == currentPageIndex,
      );
      final newPosition = newOrder.indexWhere(
        (b) => b.pageIndex == currentPageIndex,
      );

      if (newPosition < 0) {
        // Current page was removed, jump to first page in new order
        if (_pageController.hasClients && newOrder.isNotEmpty) {
          _pageController.jumpToPage(0);
          ref
              .read(navigationIndexProvider.notifier)
              .setIndex(newOrder[0].pageIndex);
        }
        return;
      }

      if (oldPosition != newPosition && _pageController.hasClients) {
        _pageController.jumpToPage(newPosition);
        ref.read(navigationIndexProvider.notifier).setIndex(currentPageIndex);
      }
    });

    _navigationIndexSubscription = ref.listenManual<int>(
      navigationIndexProvider,
      (previous, next) {
        if (!mounted) {
          return;
        }

        void animateToTab() {
          if (!_pageController.hasClients) {
            return;
          }

          final config = ref.read(navBarConfigProvider);
          final pageOrder = _getPageOrder(config);
          final position = pageOrder.indexWhere((b) => b.pageIndex == next);
          if (position == -1) return;

          final currentPage =
              (_pageController.page ?? _pageController.initialPage.toDouble())
                  .round();
          if (currentPage == position) {
            return;
          }

          _programmaticPageTarget = position;
          if (AppConstants.animationNormal == Duration.zero) {
            _pageController.jumpToPage(position);
          } else {
            _pageController.animateToPage(
              position,
              duration: AppConstants.animationNormal,
              curve: Curves.easeOutCubic,
            );
          }
        }

        if (_pageController.hasClients) {
          animateToTab();
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              animateToTab();
            }
          });
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _maybeOpenExternalPlayer(ref.read(currentSongProvider));
      _refreshLibraryDeletions();
      ref.read(updateCheckProvider.notifier).refreshIfOnline();
    });

    _playerService.playbackDesyncedNotifier.addListener(
      _onPlaybackDesyncChanged,
    );
  }

  void _refreshLibraryDeletions() {
    unawaited(_refreshLibraryDeletionsAsync());
  }

  Future<void> _refreshLibraryDeletionsAsync() async {
    try {
      final scannerService = LibraryScannerService();
      await scannerService.refreshDeletions();
      if (mounted) {
        ref.invalidate(songsProvider);
        ref.invalidate(musicFoldersProvider);
      }
    } catch (e) {
      debugPrint('Library deletion refresh failed: $e');
    }
  }

  void _onPlaybackDesyncChanged() {
    if (!mounted) return;
    final desynced = _playerService.playbackDesyncedNotifier.value;
    if (!desynced) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Playback desynced'),
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: 'Sync',
          onPressed: () {
            _playerService.syncNow();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playerService.playbackDesyncedNotifier.removeListener(
      _onPlaybackDesyncChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    _navBarVisibilitySubscription.close();
    _navBarAlwaysVisibleSubscription.close();
    _currentSongSubscription.close();
    _navigationIndexSubscription.close();
    _widgetSyncSubscription.close();
    unawaited(_widgetIntentHandler.detach());
    _pageController.dispose();
    _navBarAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(ref.read(playerServiceProvider).persistLastPlayed());
      unawaited(WidgetSyncService.instance.pushKilled());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(ref.read(playerServiceProvider).persistLastPlayed());
      unawaited(WidgetSyncService.instance.pushPaused());

      // Attempt to scrobble the current track before the app suspends.
      // Only fire if playback is not active — audio apps often keep playing
      // in the background, so treat this as a true "end" only when paused.
      final playerState = ref.read(playerProvider);
      final song = playerState.currentSong;
      if (song != null && !song.isExternal && !playerState.isPlaying) {
        final notifier = ref.read(playerProvider.notifier);
        ref
            .read(lastFmScrobbleProvider.notifier)
            .onTrackEnded(
              artist: song.artist,
              track: song.title,
              album: song.album,
              albumArtist: null,
              listenedSeconds: notifier.accumulatedListenSeconds,
              trackDurationSeconds: playerState.duration.inSeconds,
            );
      }
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(updateCheckProvider.notifier).refreshIfOnline();
      ref.read(lastFmScrobbleQueueProvider).flush().catchError((e) {
        debugPrint('[LastFm] queue flush on resume failed: $e');
      });
    }
  }

  void _onNavBarVisibilityChanged(bool isVisible) {
    if (isVisible) {
      _navBarAnimationController.reverse();
    } else {
      _navBarAnimationController.forward();
    }
  }

  void _maybeOpenExternalPlayer(Song? song) {
    if (song?.isExternal != true) {
      return;
    }
    if (!ref.read(isPlayingProvider) || NavigationHelper.isFullPlayerOpen) {
      return;
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || NavigationHelper.isFullPlayerOpen || song == null) {
        return;
      }
      NavigationHelper.navigateToFullPlayer(
        context,
        heroTag: 'external_${song.id}',
      );
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final alwaysVisible = ref.read(navBarAlwaysVisibleProvider);
    if (alwaysVisible) {
      if (!ref.read(navBarVisibleProvider)) {
        ref.read(navBarVisibleProvider.notifier).setVisible(true);
      }
      return false;
    }

    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      final currentVisibility = ref.read(navBarVisibleProvider);

      if (direction == ScrollDirection.reverse && currentVisibility) {
        ref.read(navBarVisibleProvider.notifier).setVisible(false);
      } else if (direction == ScrollDirection.forward && !currentVisibility) {
        ref.read(navBarVisibleProvider.notifier).setVisible(true);
      }
    }
    return false;
  }

  void _handleBackPress(bool didPop, dynamic result) {
    if (didPop) return;

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final backgroundColor = ref.watch(backgroundColorProvider);
    final navBarConfig = ref.watch(navBarConfigProvider);
    final pageOrder = _getPageOrder(navBarConfig);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleBackPress,
      child: AdaptiveColorProvider(
        backgroundColor: backgroundColor,
        child: Scaffold(
          backgroundColor: AppColors.background,
          extendBody: true,
          body: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Stack(
              children: [
                // Base Gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.backgroundGradient,
                  ),
                ),

                // Persistent Background - uses Riverpod
                Positioned.fill(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final ambientBackgroundEnabled = ref.watch(
                        ambientBackgroundEnabledProvider,
                      );
                      final currentSong = ref.watch(currentSongProvider);
                      return ambientBackgroundEnabled
                          ? AmbientBackground(song: currentSong)
                          : const SizedBox.shrink();
                    },
                  ),
                ),

                // Main content area with swipeable page navigation.
                PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: (position) {
                    final currentConfig = ref.read(navBarConfigProvider);
                    final currentOrder = _getPageOrder(currentConfig);
                    if (position < 0 || position >= currentOrder.length) return;
                    final enabledCount = currentConfig.orderedButtons.length;
                    if (position >= enabledCount) {
                      if (_programmaticPageTarget == position) {
                        _programmaticPageTarget = null;
                        final pageIndex = currentOrder[position].pageIndex;
                        if (ref.read(navigationIndexProvider) != pageIndex) {
                          ref
                              .read(navigationIndexProvider.notifier)
                              .setIndex(pageIndex);
                        }
                        return;
                      }
                      // Let disabled-essential pages be reachable by swipe.
                      // Still pass through silently if a programmatic
                      // animation is in-flight targeting elsewhere.
                      if (_programmaticPageTarget != null) {
                        return;
                      }
                      final pageIndex = currentOrder[position].pageIndex;
                      if (ref.read(navigationIndexProvider) != pageIndex) {
                        ref
                            .read(navigationIndexProvider.notifier)
                            .setIndex(pageIndex);
                      }
                      return;
                    }
                    // Consume the target only when we land on it.
                    if (_programmaticPageTarget == position) {
                      _programmaticPageTarget = null;
                    }
                    final pageIndex = currentOrder[position].pageIndex;
                    if (ref.read(navigationIndexProvider) != pageIndex) {
                      ref
                          .read(navigationIndexProvider.notifier)
                          .setIndex(pageIndex);
                    }
                  },
                  children: pageOrder.map((button) {
                    return _buildTab(
                      tabIndex: button.pageIndex,
                      currentIndex: currentIndex,
                      child: _buildScreen(button),
                    );
                  }).toList(),
                ),

                // Unified Bottom Bar (Mini Player + Navigation)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RepaintBoundary(
                    child: SlideTransition(
                      position: _navBarSlideAnimation,
                      child: _buildUnifiedBottomBar(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<NavBarButton> _getPageOrder(NavBarConfig config) {
    final disabledEssentials = [
      NavBarButton.menu,
      NavBarButton.songs,
      NavBarButton.settings,
    ].where((b) => !config.orderedButtons.contains(b));
    return [...config.orderedButtons, ...disabledEssentials];
  }

  Widget _buildScreen(NavBarButton button) {
    return switch (button) {
      NavBarButton.menu => MenuScreen(
        key: const ValueKey('menu'),
        onNavigateToTab: (index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        },
      ),
      NavBarButton.songs => SongsScreen(
        key: const ValueKey('songs'),
        onNavigationRequested: (index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        },
      ),
      NavBarButton.settings => const SettingsScreen(key: ValueKey('settings')),
      NavBarButton.albums => const AlbumsScreen(key: ValueKey('albums')),
      NavBarButton.artists => const ArtistsScreen(key: ValueKey('artists')),
      NavBarButton.folders => const FoldersScreen(key: ValueKey('folders')),
      NavBarButton.playlists => const PlaylistsScreen(
        key: ValueKey('playlists'),
      ),
      NavBarButton.favorites => const FavoritesScreen(
        key: ValueKey('favorites'),
      ),
      NavBarButton.search => const SearchScreen(key: ValueKey('search')),
    };
  }

  Widget _buildTab({
    required int tabIndex,
    required int currentIndex,
    required Widget child,
  }) {
    return RepaintBoundary(
      child: TickerMode(enabled: currentIndex == tabIndex, child: child),
    );
  }

  Widget _buildUnifiedBottomBar() {
    final currentIndex = ref.watch(navigationIndexProvider);
    final navBarConfig = ref.watch(navBarConfigProvider);

    return FlickNavBar(
      currentIndex: currentIndex,
      config: navBarConfig,
      onTap: (index) {
        if (ref.read(navigationIndexProvider) != index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        }
      },
      showMiniPlayer: true,
      miniPlayerWidget: const _EmbeddedMiniPlayer(),
    );
  }
}

/// Embedded mini player widget that uses Riverpod for state.
class _EmbeddedMiniPlayer extends ConsumerWidget {
  const _EmbeddedMiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        FocusScope.of(context).unfocus();
        final result = await NavigationHelper.navigateToFullPlayer(
          context,
          heroTag: 'mini_player_art',
        );
        // Navigate to the returned tab index if provided
        if (result != null && context.mounted) {
          ref.read(navigationIndexProvider.notifier).setIndex(result);
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceLight.withValues(alpha: 0.86),
              AppColors.surface.withValues(alpha: 0.94),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color.fromARGB(
              108,
              255,
              255,
              255,
            ).withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Progress Bar at bottom
              Consumer(
                builder: (context, ref, _) {
                  final progress = ref.watch(progressProvider);
                  if (progress == 0) return const SizedBox.shrink();

                  return Align(
                    alignment: Alignment.bottomLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(height: 2, color: AppColors.accent),
                    ),
                  );
                },
              ),

              Row(
                children: [
                  // Album Art
                  Hero(
                    tag: 'mini_player_art',
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child: currentSong.albumArt != null
                            ? CachedImageWidget(
                                imagePath: currentSong.albumArt!,
                                fit: BoxFit.cover,
                                useThumbnail: true,
                                thumbnailWidth: 128,
                                thumbnailHeight: 128,
                              )
                            : const Icon(
                                LucideIcons.music,
                                size: 22,
                                color: AppColors.textTertiary,
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Song Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 12,
                            color: context.adaptiveTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Play/Pause Button
                  Consumer(
                    builder: (context, ref, _) {
                      final isPlaying = ref.watch(isPlayingProvider);
                      return IconButton(
                        onPressed: () =>
                            ref.read(playerProvider.notifier).togglePlayPause(),
                        icon: Icon(
                          isPlaying ? LucideIcons.pause : LucideIcons.play,
                          color: context.adaptiveTextPrimary,
                          size: 20,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompletedProvider);
    final appPreferences = ref.watch(appPreferencesProvider);

    // Apply animation and haptic preferences globally.
    AppConstants.setAnimationsEnabled(appPreferences.animationsEnabled);
    AppHaptics.setEnabled(appPreferences.hapticsEnabled);

    final child = onboardingComplete
        ? const MainShell()
        : const OnboardingScreen();

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: !appPreferences.animationsEnabled),
      child: child,
    );
  }
}
