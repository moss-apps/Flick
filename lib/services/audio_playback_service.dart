import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flick/services/alac_converter_service.dart';
import 'package:flick/core/utils/dev_log.dart';

/// Enhanced audio playback service with lossless conversion support.
///
/// This service automatically converts supported files to WAV before playback
/// to ensure compatibility across all platforms, especially Android.
class AudioPlaybackService {
  final AudioPlayer _player;
  final Map<String, String> _conversionCache = {};
  AlacAudioSource? _currentAlacSource;

  AudioPlaybackService(this._player);

  /// Play a file with automatic ALAC conversion if needed
  Future<void> playFile(String filePath) async {
    try {
      // Clean up previous ALAC source
      await _cleanupCurrentAlacSource();

      String playablePath = filePath;

      // Check if WAV conversion is needed.
      if (AlacConverterService.requiresWavConversion(filePath)) {
        devLog('Lossless source detected, converting to WAV...');

        // Check cache first
        if (_conversionCache.containsKey(filePath)) {
          playablePath = _conversionCache[filePath]!;
          devLog('Using cached conversion: $playablePath');
        } else {
          // Convert file
          final alacSource = AlacAudioSource(filePath);
          playablePath = await alacSource.getPlayablePath();
          _currentAlacSource = alacSource;
          _conversionCache[filePath] = playablePath;
          devLog('Converted to: $playablePath');
        }
      }

      // Play the file
      await _player.setFilePath(playablePath);
      await _player.play();
    } catch (e) {
      devLog('Error playing file: $e');
      rethrow;
    }
  }

  /// Stop playback and cleanup
  Future<void> stop() async {
    await _player.stop();
    await _cleanupCurrentAlacSource();
  }

  /// Dispose and cleanup all resources
  Future<void> dispose() async {
    await _player.dispose();
    await _cleanupCurrentAlacSource();
    await _clearConversionCache();
  }

  /// Clean up current ALAC source
  Future<void> _cleanupCurrentAlacSource() async {
    if (_currentAlacSource != null) {
      await _currentAlacSource!.dispose();
      _currentAlacSource = null;
    }
  }

  /// Clear all cached conversions
  Future<void> _clearConversionCache() async {
    for (final convertedPath in _conversionCache.values) {
      try {
        final file = File(convertedPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        devLog('Failed to delete cached file: $e');
      }
    }
    _conversionCache.clear();
  }

  /// Get audio player instance
  AudioPlayer get player => _player;
}

/// Factory for creating audio playback service
class AudioPlaybackServiceFactory {
  static AudioPlaybackService create() {
    final player = AudioPlayer();
    return AudioPlaybackService(player);
  }
}
