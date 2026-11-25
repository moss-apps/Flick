import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/shuffle_mode.dart';
import 'package:flick/services/car/car_library.dart';
import 'package:flick/services/car/car_models.dart';
import 'package:flick/services/player_service.dart';

/// Most songs one `enqueue` adds.
const int kCarEnqueueMax = 50;

const Duration _commandBudget = Duration(seconds: 8);

/// Sends one call per [window] per key, however many notifications arrive.
class CarChangeCoalescer {
  CarChangeCoalescer({
    required this.send,
    this.window = const Duration(milliseconds: 150),
  });

  final void Function(String what) send;
  final Duration window;
  final Map<String, Timer> _pending = {};

  /// Schedules `send(what)` at the end of the window; notifications that
  /// arrive before it fires are absorbed into the same call.
  void notify(String what) {
    if (_pending.containsKey(what)) return;
    _pending[what] = Timer(window, () {
      _pending.remove(what);
      send(what);
    });
  }

  void dispose() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
  }
}

/// Channel `com.mossapps.flick/car`: answers the car side's questions about
/// the library and the queue, runs its commands, and tells it when something
/// it may have cached has changed. Dart stays authoritative for all state.
///
/// Contract: docs/ANDROID_AUTO_DESIGN.md, section 4.3.
class CarBridge {
  CarBridge._({CarLibrary? library}) : _library = library ?? CarLibrary();

  static final CarBridge instance = CarBridge._();

  static const MethodChannel _channel = MethodChannel('com.mossapps.flick/car');

  final CarLibrary _library;
  late final CarChangeCoalescer _changes = CarChangeCoalescer(
    send: (what) => unawaited(_sendChanged(what)),
  );

  bool _initialized = false;
  bool _attached = false;
  Future<void>? _prepared;

  /// Registers the channel handler. Cheap and safe to call before anything
  /// else: it touches no database and builds no player.
  void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleCall);
  }

  /// Starts watching the player and the library on the first request. Until
  /// the car has asked for something it holds nothing that could go stale.
  void _attach() {
    if (_attached) return;
    _attached = true;

    final player = PlayerService();
    void watch(Listenable source, String what) {
      source.addListener(() => _changes.notify(what));
    }

    watch(player.queueNotifier, 'queue');
    watch(player.upNextNotifier, 'queue');
    watch(player.playbackContextNotifier, 'queue');
    watch(player.shuffleModeNotifier, 'modes');
    watch(player.loopModeNotifier, 'modes');
    watch(player.currentSongNotifier, 'track');
    // Favorites change without touching the song table.
    watch(player.favoriteNotificationToggleNotifier, 'library');

    try {
      SongRepository().watchSongs().listen((_) {
        _library.invalidate();
        _changes.notify('library');
      }, onError: (Object e) => devLog('Car: library watch failed: $e'));
    } catch (e) {
      devLog('Car: library watch unavailable: $e');
    }
  }

  Future<void> _sendChanged(String what) async {
    try {
      await _channel.invokeMethod<void>('changed', {'what': what});
    } on MissingPluginException {
      // No car side registered (yet).
    } catch (e) {
      devLog('Car: changed($what) failed: $e');
    }
  }

  /// A car can connect with the app closed, where no first frame ever runs the
  /// launch preparation. Await it once before anything that starts playback.
  Future<void> _ready() {
    return _prepared ??= PlayerService().prepareForAppLaunch().catchError((
      Object e,
    ) {
      devLog('Car: audio prewarm failed: $e');
      _prepared = null;
    });
  }

  Future<Object?> _handleCall(MethodCall call) async {
    _attach();
    try {
      return await _dispatch(call.method, _arguments(call));
    } on MissingPluginException {
      rethrow;
    } on PlatformException {
      rethrow;
    } on CarException catch (e) {
      throw PlatformException(code: e.code, message: e.message);
    } catch (e, stack) {
      devLog('Car: ${call.method} failed: $e\n$stack');
      throw PlatformException(code: 'car_error', message: '$e');
    }
  }

  Future<Object?> _dispatch(String method, Map<String, Object?> args) async {
    final player = PlayerService();
    switch (method) {
      case 'status':
        return _status();
      case 'home':
        return _library.home(
          resume: player.currentSongNotifier.value,
          queueCount: player.upcoming.total,
        );
      case 'list':
        return _library.list(
          _requiredString(args, 'kind'),
          limit: args['limit'],
        );
      case 'collection':
        return _library.collection(
          _requiredString(args, 'kind'),
          _optionalString(args, 'id') ?? '',
          limit: args['limit'],
        );
      case 'search':
        return _library.search(
          _optionalString(args, 'query') ?? '',
          limit: args['limit'],
        );
      case 'play':
        await _bounded(_play(args));
        return null;
      case 'enqueue':
        return _enqueue(args);
      case 'queue':
        return carQueueMap(
          current: player.currentSongNotifier.value,
          upcoming: player.upcoming,
          limit: carLimit(args['limit'], fallback: 100),
          context: player.playbackContextNotifier.value,
          shuffle: player.isShuffleNotifier.value,
          loop: player.loopModeNotifier.value.sessionRepeat,
        );
      case 'jump':
        await _bounded(_jump(args));
        return null;
      case 'clearQueue':
        await player.clearQueue();
        return null;
      case 'toggleShuffle':
        await _bounded(_ready().then((_) => player.toggleShuffle()));
        return null;
      case 'cycleLoop':
        await _bounded(_ready().then((_) => player.toggleLoopMode()));
        return null;
      case 'toggleFavorite':
        await player.toggleCurrentFavorite();
        return null;
      case 'resume':
        await _bounded(_ready().then((_) => player.resume()));
        return null;
      case 'playSearch':
        await _bounded(_playSearch(args));
        return null;
    }
    throw MissingPluginException('Unhandled car method: $method');
  }

  /// A playback command is answered once it is under way. The car gives up on
  /// a request after 10 s, and a slow engine start must not turn into an error
  /// reply for playback that then begins anyway.
  Future<void> _bounded(Future<void> command) {
    return command.timeout(
      _commandBudget,
      onTimeout: () => devLog('Car: command still running after the budget'),
    );
  }

  Future<Map<String, Object?>> _status() async {
    try {
      final count = await SongRepository().getSongCount();
      return {'ready': true, 'songCount': count};
    } catch (e) {
      devLog('Car: status failed: $e');
      return {'ready': false, 'songCount': 0};
    }
  }

  Future<void> _play(Map<String, Object?> args) async {
    final kind = _playableKind(args);
    final playable = await _library.resolve(
      kind,
      _optionalString(args, 'id') ?? '',
    );
    await _playResolved(
      playable,
      trackId: _optionalString(args, 'trackId'),
      shuffle: args['shuffle'] == true,
    );
  }

  Future<void> _playSearch(Map<String, Object?> args) async {
    final query = _optionalString(args, 'query') ?? '';
    final playable = await _library.resolveVoice(query);
    if (playable == null) {
      throw CarException('not_found', 'Nothing matches "$query"');
    }
    await _playResolved(playable);
  }

  /// Plays the complete list. [shuffle] turns shuffle on when it is off (it
  /// never turns it off), and starts anywhere in the list like a tap on the
  /// phone's shuffle button.
  Future<void> _playResolved(
    CarPlayable playable, {
    String? trackId,
    bool shuffle = false,
  }) async {
    if (playable.songs.isEmpty) {
      throw const CarException('not_found', 'Nothing to play');
    }
    await _ready();
    final player = PlayerService();
    final start = carStartSong(
      playable.songs,
      trackId: trackId,
      shuffle: shuffle,
    );
    if (shuffle && !player.isShuffleNotifier.value) {
      await player.setShuffleMode(ShuffleMode.songs);
    }
    await player.play(
      start,
      playlist: playable.songs,
      context: playable.context,
    );
  }

  Future<Map<String, Object?>> _enqueue(Map<String, Object?> args) async {
    final kind = _playableKind(args);
    final playable = await _library.resolve(
      kind,
      _optionalString(args, 'id') ?? '',
    );
    final player = PlayerService();
    final songs = playable.songs.take(kCarEnqueueMax).toList();
    for (final song in songs) {
      await player.addToQueue(song);
    }
    return {'added': songs.length};
  }

  Future<void> _jump(Map<String, Object?> args) async {
    final section = _requiredString(args, 'section');
    final index = args['index'];
    if (index is! num) {
      throw const CarException('bad_args', 'Missing "index"');
    }
    await _ready();
    final player = PlayerService();
    // Read the rows and jump in the same turn so they cannot disagree.
    final row = carJumpRow(player.upcoming, section, index.toInt());
    if (row == null) {
      throw CarException('bad_args', 'No row $index in "$section"');
    }
    await player.playFromUpcomingIndex(row);
  }

  // --------------------------------------------------------------- arguments

  Map<String, Object?> _arguments(MethodCall call) {
    final raw = call.arguments;
    return raw is Map ? Map<String, Object?>.from(raw) : const {};
  }

  String _requiredString(Map<String, Object?> args, String key) {
    final value = _optionalString(args, key);
    if (value == null) throw CarException('bad_args', 'Missing "$key"');
    return value;
  }

  String? _optionalString(Map<String, Object?> args, String key) {
    final value = args[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  String _playableKind(Map<String, Object?> args) {
    final kind = _requiredString(args, 'kind');
    if (!CarKind.playable.contains(kind)) {
      throw CarException('bad_args', 'Unknown collection kind "$kind"');
    }
    return kind;
  }
}
