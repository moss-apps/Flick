import 'dart:async';

import 'package:flutter/widgets.dart';

// ponytail: refcounted pause so independent drivers (fling gate, audio
// preload service) can hold the pause without one's release clobbering
// the other. Flush deferred resolvers only when the count actually hits 0.
int _artworkExtractionPauses = 0;
final List<VoidCallback> _pendingArtworkResolvers = <VoidCallback>[];

bool get artworkExtractionPaused => _artworkExtractionPauses > 0;

void pauseArtworkExtraction(bool paused) {
  if (paused) {
    _artworkExtractionPauses++;
    return;
  }
  if (_artworkExtractionPauses > 0) _artworkExtractionPauses--;
  if (_artworkExtractionPauses == 0) {
    final resolvers = List<VoidCallback>.of(_pendingArtworkResolvers);
    _pendingArtworkResolvers.clear();
    for (final r in resolvers) {
      r();
    }
  }
}

void enqueueArtworkResolver(VoidCallback cb) {
  _pendingArtworkResolvers.add(cb);
}

/// Mix this onto a screen's [State] and route its [ScrollNotification]s to
/// [onScrollNotification] to keep embedded-artwork extraction paused during
/// flings. Call [disposeArtworkGate] from [State.dispose].
// ponytail: shared helper beats triplicating the timer logic across
// album/artist/playlist screens.
mixin ArtworkExtractionScrollGate {
  static const Duration _settleDelay = Duration(milliseconds: 150);

  Timer? _artworkGate;

  bool onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      _artworkGate?.cancel();
      _artworkGate = null;
      pauseArtworkExtraction(false);
    } else if (notification is ScrollUpdateNotification ||
        notification is UserScrollNotification ||
        notification is OverscrollNotification) {
      pauseArtworkExtraction(true);
      _artworkGate?.cancel();
      _artworkGate = Timer(_settleDelay, () => pauseArtworkExtraction(false));
    }
    return true;
  }

  void disposeArtworkGate() {
    _artworkGate?.cancel();
    // Release the global pause so extraction isn't left frozen when the
    // route is popped mid-scroll.
    pauseArtworkExtraction(false);
  }
}