import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/song.dart';
import '../player_service.dart';
import '../remote_source_service.dart';
import 'cast_content_server.dart';
import 'cast_device.dart';
import 'dlna_backend.dart';
import 'chromecast_backend.dart';

// ponytail: orchestrates DLNA + Chromecast backends; drives PlayerService notifiers
// so the UI works unchanged while casting. Mutual import with PlayerService is fine
// in Dart (no constructor-time cycle; both are lazy singletons).
//
// System integration: while casting, the media notification switches the
// MediaSession to remote volume (setPlaybackToRemote) so the system volume
// panel shows the cast target and hardware keys drive it. DLNA targets are
// additionally published as MediaRouter routes (native DlnaRouteProvider) so
// One UI / output switchers see a real remote output.
class CastingService {
  CastingService._() {
    _listenChromecastEvents();
  }
  static final CastingService instance = CastingService._();

  static const _dlnaRouteChannel = MethodChannel(
    'com.mossapps.flick/dlna_route',
  );

  final DlnaBackend _dlna = DlnaBackend();
  final ChromecastBackend _chromecast = ChromecastBackend();

  final ValueNotifier<List<CastDevice>> devicesNotifier =
      ValueNotifier<List<CastDevice>>(const []);
  final ValueNotifier<CastDevice?> activeDeviceNotifier =
      ValueNotifier<CastDevice?>(null);
  final ValueNotifier<bool> isActiveNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isDiscoveringNotifier = ValueNotifier<bool>(false);

  /// Remote volume 0..1 while casting; null when local. Mirrors the TV-side
  /// value so the system VolumeProvider and in-app slider stay in sync.
  final ValueNotifier<double?> remoteVolumeNotifier =
      ValueNotifier<double?>(null);

  CastDevice? _activeDevice;
  Song? _currentSong;
  Timer? _pollTimer;
  Timer? _discoverCooldown;
  StreamSubscription<Map<String, dynamic>>? _ccEventsSub;
  bool _wasPlayingBeforeCast = false;
  bool _tearingDown = false;

  bool get isActive => _activeDevice != null;
  CastDevice? get activeDevice => _activeDevice;
  Song? get currentSong => _currentSong;

  Future<void> discover({Duration timeout = const Duration(seconds: 4)}) async {
    isDiscoveringNotifier.value = true;
    try {
      final results = await Future.wait<dynamic>([
        _dlna.discover(timeout: timeout),
        _chromecast.discover(),
      ]);
      final dlna = results[0] as List<CastDevice>;
      final cc = results[1] as List<CastDevice>;
      devicesNotifier.value = [...dlna, ...cc];
      _publishDlnaRoutes(dlna);
    } finally {
      isDiscoveringNotifier.value = false;
    }
  }

  void startContinuousDiscovery() {
    if (_discoverCooldown != null) return;
    discover();
    _discoverCooldown = Timer.periodic(
      const Duration(seconds: 10),
      (_) => discover(),
    );
  }

  void stopContinuousDiscovery() {
    _discoverCooldown?.cancel();
    _discoverCooldown = null;
  }

  Future<void> connect(CastDevice device) async {
    if (_activeDevice?.id == device.id) return;
    final ps = PlayerService();
    final wasPlaying = ps.isPlayingNotifier.value;
    final resumeSong = ps.currentSongNotifier.value;
    final resumePosition = ps.positionNotifier.value;

    // ponytail: switching targets — the old session must die without
    // resurrecting local playback mid-handoff.
    await disconnect(resumeLocal: false);
    _wasPlayingBeforeCast = wasPlaying;

    _activeDevice = device;
    activeDeviceNotifier.value = device;
    isActiveNotifier.value = true;
    remoteVolumeNotifier.value = null;

    if (device.backend == CastBackend.chromecast) {
      await _chromecast.connect(device);
      final v = await _chromecast.getVolume();
      if (v != null && v >= 0) remoteVolumeNotifier.value = v.clamp(0.0, 1.0);
    } else {
      _selectDlnaRoute(device);
    }

    // ponytail: local engine must yield the moment a cast target takes over —
    // otherwise phone + TV play simultaneously.
    if (ps.isPlayingNotifier.value) {
      await ps.pause();
    }

    if (wasPlaying && resumeSong != null) {
      await delegatePlay(resumeSong);
      if (resumePosition.inSeconds > 3) {
        await delegateSeek(resumePosition);
      }
    }

    unawaited(ps.refreshNotificationState());
  }

  Future<void> disconnect({bool resumeLocal = true}) async {
    if (_activeDevice == null) return;
    _tearingDown = true;
    _pollTimer?.cancel();
    _pollTimer = null;

    final wasPlaying = _wasPlayingBeforeCast;
    _wasPlayingBeforeCast = false;
    final dev = _activeDevice!;
    _activeDevice = null;
    _currentSong = null;
    activeDeviceNotifier.value = null;
    isActiveNotifier.value = false;
    remoteVolumeNotifier.value = null;

    try {
      if (dev.backend == CastBackend.chromecast) {
        await _chromecast.disconnect();
      } else {
        if (dev.controlUrl != null) {
          try {
            await _dlna.stop(dev.controlUrl!);
          } catch (_) {}
        }
        _unselectDlnaRoute();
      }
      await CastContentServer.instance.stop();
    } finally {
      _tearingDown = false;
    }

    final ps = PlayerService();
    if (resumeLocal && wasPlaying && ps.currentSongNotifier.value != null) {
      // Local engine may hold a stale track after remote-side song changes;
      // replay the current song so resume lands on what the UI shows.
      final song = ps.currentSongNotifier.value!;
      final pos = ps.positionNotifier.value;
      unawaited(ps.play(song));
      if (pos.inSeconds > 3) {
        unawaited(
          ps.seek(pos).then((_) => ps.resume()).catchError((_) {}),
        );
      }
    }
    unawaited(ps.refreshNotificationState());
  }

  // Called by PlayerService._playInternal hook. Returns true if handled.
  Future<bool> delegatePlay(Song song) async {
    if (_activeDevice == null) return false;
    _currentSong = song;
    final ps = PlayerService();
    ps.currentSongNotifier.value = song;
    ps.durationNotifier.value = song.duration;
    ps.positionNotifier.value = Duration.zero;
    final resolved = await RemoteSourceService.instance.resolveHttpPlayback(
      song,
    );
    final url = resolved?.url ?? await _serveFromPhone(song);
    if (url == null) {
      // Content-URI locals and unresolvable sources stay local-only.
      return false;
    }
    final dev = _activeDevice!;
    if (dev.backend == CastBackend.dlna) {
      final control = dev.controlUrl;
      if (control == null) return false;
      await _dlna.setUri(control, url, title: song.title);
      await _dlna.play(control);
      _startDlnaPolling(control, dev.renderingControlUrl);
    } else {
      await _chromecast.load(url, title: song.title, artist: song.artist);
    }
    ps.isPlayingNotifier.value = true;
    return true;
  }

  Future<void> delegatePause() async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.pause(_activeDevice!.controlUrl!);
    } else {
      await _chromecast.pause();
    }
    PlayerService().isPlayingNotifier.value = false;
  }

  Future<void> delegateResume() async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.play(_activeDevice!.controlUrl!);
    } else {
      await _chromecast.resume();
    }
    PlayerService().isPlayingNotifier.value = true;
  }

  Future<void> delegateSeek(Duration position) async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.seek(_activeDevice!.controlUrl!, position);
    } else {
      await _chromecast.seek(position);
    }
    PlayerService().positionNotifier.value = position;
  }

  Future<void> delegateStop() async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.stop(_activeDevice!.controlUrl!);
    } else {
      await _chromecast.stop();
    }
  }

  Future<void> delegateSetVolume(double volume) async {
    if (_activeDevice == null) return;
    final v = volume.clamp(0.0, 1.0);
    if (_activeDevice!.backend == CastBackend.dlna) {
      final rc = _activeDevice!.renderingControlUrl;
      if (rc == null) return;
      await _dlna.setVolume(rc, (v * 100).round().clamp(0, 100));
    } else {
      await _chromecast.setVolume(v);
    }
    remoteVolumeNotifier.value = v;
  }

  // ==================== native route bridge ====================

  void _publishDlnaRoutes(List<CastDevice> dlnaDevices) {
    _invokeDlnaRoute('publishRoutes', {
      'routes': [
        for (final d in dlnaDevices)
          {'id': d.id, 'name': d.name},
      ],
    });
  }

  void _selectDlnaRoute(CastDevice d) =>
      _invokeDlnaRoute('selectRoute', {'id': d.id});

  void _unselectDlnaRoute() => _invokeDlnaRoute('unselectRoute', {});

  void _invokeDlnaRoute(String method, Map<String, dynamic> args) {
    // ignore: unawaited_futures
    _dlnaRouteChannel.invokeMethod<void>(method, args).catchError((_) {});
  }

  // ==================== chromecast native events ====================

  void _listenChromecastEvents() {
    if (_ccEventsSub != null) return;
    _ccEventsSub = _chromecast.events.listen(
      (e) {
        final event = e['event'] as String?;
        switch (event) {
          case 'sessionEnded':
            if (!_tearingDown && isActive) {
              unawaited(disconnect());
            }
            break;
          case 'status':
            _handleCcStatus(e);
            break;
          case 'volume':
            final v = (e['volume'] as num?)?.toDouble();
            if (v != null) {
              remoteVolumeNotifier.value = v.clamp(0.0, 1.0);
            }
            break;
          case 'dlnaRouteSelected':
            _handleDlnaRouteSelected(e);
            break;
          case 'dlnaRouteUnselected':
            if (!_tearingDown && _activeDevice?.backend == CastBackend.dlna) {
              unawaited(disconnect());
            }
            break;
          case 'dlnaVolume':
            final v = (e['volume'] as num?)?.toDouble();
            if (v != null && _activeDevice != null) {
              unawaited(PlayerService().setVolume(v));
            }
            break;
        }
      },
      onError: (_) {},
      onDone: () => _ccEventsSub = null,
    );
  }

  void _handleCcStatus(Map<String, dynamic> e) {
    if (_activeDevice?.backend != CastBackend.chromecast) return;
    final ps = PlayerService();
    final position = (e['position'] as num?)?.toInt();
    final duration = (e['duration'] as num?)?.toInt();
    final playing = e['playing'] as bool?;
    if (playing != null) ps.isPlayingNotifier.value = playing;
    if (position != null) ps.positionNotifier.value = Duration(milliseconds: position);
    if (duration != null && duration > 0) {
      ps.durationNotifier.value = Duration(milliseconds: duration);
    }
  }

  void _handleDlnaRouteSelected(Map<String, dynamic> e) {
    if (_tearingDown || isActive) return;
    final id = e['id'] as String?;
    if (id == null) return;
    final match = devicesNotifier.value.where((d) => d.id == id).firstOrNull;
    if (match != null && match.backend == CastBackend.dlna) {
      unawaited(connect(match));
    }
  }

  /// Last-resort cast source: serve the bytes from this phone via the
  /// embedded HTTP server. Covers local files, SMB, and cached network songs
  /// (including formats the local engine can't decode — the renderer decodes).
  Future<String?> _serveFromPhone(Song song) async {
    try {
      String? path;
      if (song.isNetworkSource) {
        path = await RemoteSourceService.instance.ensureLocal(song);
      } else {
        final p = song.filePath;
        if (p != null && !p.startsWith('content://') && File(p).existsSync()) {
          path = p;
        }
      }
      if (path == null) return null;
      final ext = song.fileType.toLowerCase();
      final title = song.title.replaceAll(RegExp(r'[^A-Za-z0-9._\- ]'), '');
      return await CastContentServer.instance.serve(
        path,
        filename: '${title.isEmpty ? 'track' : title}.$ext',
      );
    } catch (_) {
      return null;
    }
  }

  void _startDlnaPolling(String controlUrl, String? renderingControlUrl) {
    _pollTimer?.cancel();
    var tick = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_activeDevice == null) return;
      final info = await _dlna.getPosition(controlUrl);
      if (info == null) return;
      final ps = PlayerService();
      ps.positionNotifier.value = info.position;
      if (info.duration.inMilliseconds > 0) {
        ps.durationNotifier.value = info.duration;
      }
      ps.isPlayingNotifier.value = info.playing;
      // Volume poll is half-rate; each tick is already 2 SOAP calls.
      if (renderingControlUrl != null && tick++ % 2 == 0) {
        final v = await _dlna.getVolume(renderingControlUrl);
        if (v != null) remoteVolumeNotifier.value = v / 100.0;
      }
    });
  }
}
