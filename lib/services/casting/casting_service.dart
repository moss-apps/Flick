import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/song.dart';
import '../player_service.dart';
import '../remote_source_service.dart';
import 'cast_device.dart';
import 'dlna_backend.dart';
import 'chromecast_backend.dart';

// ponytail: orchestrates DLNA + Chromecast backends; drives PlayerService notifiers
// so the UI works unchanged while casting. Mutual import with PlayerService is fine
// in Dart (no constructor-time cycle; both are lazy singletons).
class CastingService {
  CastingService._();
  static final CastingService instance = CastingService._();

  final DlnaBackend _dlna = DlnaBackend();
  final ChromecastBackend _chromecast = ChromecastBackend();

  final ValueNotifier<List<CastDevice>> devicesNotifier =
      ValueNotifier<List<CastDevice>>(const []);
  final ValueNotifier<CastDevice?> activeDeviceNotifier = ValueNotifier<CastDevice?>(null);
  final ValueNotifier<bool> isActiveNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isDiscoveringNotifier = ValueNotifier<bool>(false);

  CastDevice? _activeDevice;
  Song? _currentSong;
  Timer? _pollTimer;
  Timer? _discoverCooldown;

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
    } finally {
      isDiscoveringNotifier.value = false;
    }
  }

  void startContinuousDiscovery() {
    if (_discoverCooldown != null) return;
    discover();
    _discoverCooldown = Timer.periodic(const Duration(seconds: 10), (_) => discover());
  }

  void stopContinuousDiscovery() {
    _discoverCooldown?.cancel();
    _discoverCooldown = null;
  }

  Future<void> connect(CastDevice device) async {
    await disconnect();
    _activeDevice = device;
    activeDeviceNotifier.value = device;
    isActiveNotifier.value = true;
    if (device.backend == CastBackend.chromecast) {
      await _chromecast.connect(device);
    }
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_activeDevice?.backend == CastBackend.chromecast) {
      await _chromecast.disconnect();
    } else if (_activeDevice != null && _currentSong != null) {
      await _dlna.stop(_controlUrl(_activeDevice!));
    }
    _activeDevice = null;
    _currentSong = null;
    activeDeviceNotifier.value = null;
    isActiveNotifier.value = false;
  }

  // Called by PlayerService._playInternal hook. Returns true if handled.
  Future<bool> delegatePlay(Song song) async {
    if (_activeDevice == null) return false;
    _currentSong = song;
    final ps = PlayerService();
    ps.currentSongNotifier.value = song;
    ps.durationNotifier.value = song.duration;
    ps.positionNotifier.value = Duration.zero;
    final resolved = await RemoteSourceService.instance.resolveHttpPlayback(song);
    final url = resolved?.url;
    if (url == null) {
      // Local files can't be cast without an embedded HTTP server (deferred).
      return false;
    }
    final dev = _activeDevice!;
    if (dev.backend == CastBackend.dlna) {
      final control = _controlUrl(dev);
      await _dlna.setUri(control, url, title: song.title);
      await _dlna.play(control);
      _startDlnaPolling(control);
    } else {
      await _chromecast.load(url, title: song.title, artist: song.artist);
    }
    ps.isPlayingNotifier.value = true;
    return true;
  }

  Future<void> delegatePause() async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.pause(_controlUrl(_activeDevice!));
    } else {
      await _chromecast.pause();
    }
    PlayerService().isPlayingNotifier.value = false;
  }

  Future<void> delegateResume() async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.play(_controlUrl(_activeDevice!));
    } else {
      await _chromecast.resume();
    }
    PlayerService().isPlayingNotifier.value = true;
  }

  Future<void> delegateSeek(Duration position) async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.seek(_controlUrl(_activeDevice!), position);
    } else {
      await _chromecast.seek(position);
    }
    PlayerService().positionNotifier.value = position;
  }

  Future<void> delegateStop() async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.stop(_controlUrl(_activeDevice!));
    } else {
      await _chromecast.stop();
    }
  }

  Future<void> delegateSetVolume(double volume) async {
    if (_activeDevice == null) return;
    if (_activeDevice!.backend == CastBackend.dlna) {
      await _dlna.setVolume(_controlUrl(_activeDevice!), (volume * 100).round().clamp(0, 100));
    } else {
      await _chromecast.setVolume(volume);
    }
  }

  String _controlUrl(CastDevice d) => d.iconUrl!; // DLNA: controlURL stashed here at discovery

  void _startDlnaPolling(String controlUrl) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_activeDevice == null) return;
      final info = await _dlna.getPosition(controlUrl);
      if (info == null) return;
      final ps = PlayerService();
      ps.positionNotifier.value = info.position;
      if (info.duration.inMilliseconds > 0) ps.durationNotifier.value = info.duration;
      ps.isPlayingNotifier.value = info.playing;
    });
  }
}
