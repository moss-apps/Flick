import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

enum PlayerActionButton {
  lyrics,
  favorites,
  visualizer,
  ratings,
  queue,
  sleepTimer,
  share,
  usbVolume,
  equalizer,
  volume,
}

extension PlayerActionButtonX on PlayerActionButton {
  String get storageValue {
    switch (this) {
      case PlayerActionButton.lyrics:
        return 'lyrics';
      case PlayerActionButton.favorites:
        return 'favorites';
      case PlayerActionButton.visualizer:
        return 'visualizer';
      case PlayerActionButton.ratings:
        return 'ratings';
      case PlayerActionButton.queue:
        return 'queue';
      case PlayerActionButton.sleepTimer:
        return 'sleep_timer';
      case PlayerActionButton.share:
        return 'share';
      case PlayerActionButton.usbVolume:
        return 'usb_volume';
      case PlayerActionButton.equalizer:
        return 'equalizer';
      case PlayerActionButton.volume:
        return 'volume';
    }
  }

  String get label {
    switch (this) {
      case PlayerActionButton.lyrics:
        return 'Lyrics';
      case PlayerActionButton.favorites:
        return 'Favorites';
      case PlayerActionButton.visualizer:
        return 'Visualizer';
      case PlayerActionButton.ratings:
        return 'Rating';
      case PlayerActionButton.queue:
        return 'Queue';
      case PlayerActionButton.sleepTimer:
        return 'Sleep Timer';
      case PlayerActionButton.share:
        return 'Share';
      case PlayerActionButton.usbVolume:
        return 'USB Volume';
      case PlayerActionButton.equalizer:
        return 'Equalizer';
      case PlayerActionButton.volume:
        return 'Volume';
    }
  }

  IconData get icon {
    switch (this) {
      case PlayerActionButton.lyrics:
        return LucideIcons.fileText;
      case PlayerActionButton.favorites:
        return Icons.favorite_border;
      case PlayerActionButton.visualizer:
        return Icons.graphic_eq_rounded;
      case PlayerActionButton.ratings:
        return LucideIcons.star;
      case PlayerActionButton.queue:
        return LucideIcons.listMusic;
      case PlayerActionButton.sleepTimer:
        return LucideIcons.moonStar;
      case PlayerActionButton.share:
        return LucideIcons.share2;
      case PlayerActionButton.usbVolume:
        return LucideIcons.volume2;
      case PlayerActionButton.equalizer:
        return LucideIcons.slidersHorizontal;
      case PlayerActionButton.volume:
        return LucideIcons.volume;
    }
  }

  static PlayerActionButton fromStorageValue(String? value) {
    switch (value) {
      case 'favorites':
        return PlayerActionButton.favorites;
      case 'visualizer':
        return PlayerActionButton.visualizer;
      case 'ratings':
        return PlayerActionButton.ratings;
      case 'queue':
        return PlayerActionButton.queue;
      case 'sleep_timer':
        return PlayerActionButton.sleepTimer;
      case 'share':
        return PlayerActionButton.share;
      case 'usb_volume':
        return PlayerActionButton.usbVolume;
      case 'equalizer':
        return PlayerActionButton.equalizer;
      case 'volume':
        return PlayerActionButton.volume;
      case 'lyrics':
      default:
        return PlayerActionButton.lyrics;
    }
  }
}