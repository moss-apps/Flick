import 'package:flutter/material.dart';

import '../../../data/repositories/recently_played_repository.dart';
import 'replay_style.dart';

enum ReplayLook { signal, night, artwork }

extension ReplayLookX on ReplayLook {
  String get label => switch (this) {
    ReplayLook.signal => 'Signal',
    ReplayLook.night => 'Night',
    ReplayLook.artwork => 'Artwork',
  };
}

enum ReplayMetric { trackTime, songs, artists, activeDays, peakHour }

extension ReplayMetricX on ReplayMetric {
  String get label => switch (this) {
    ReplayMetric.trackTime => 'Track time',
    ReplayMetric.songs => 'Songs',
    ReplayMetric.artists => 'Artists',
    ReplayMetric.activeDays => 'Active days',
    ReplayMetric.peakHour => 'Peak hour',
  };

  String value(ListeningRecap recap) => switch (this) {
    ReplayMetric.trackTime => ReplayStyle.durationLabel(
      recap.totalListeningTime,
    ),
    ReplayMetric.songs => '${recap.uniqueSongs}',
    ReplayMetric.artists => '${recap.uniqueArtists}',
    ReplayMetric.activeDays => '${recap.activeDays}',
    ReplayMetric.peakHour => ReplayStyle.peakHour(recap.peakHour),
  };
}

/// A small, deliberately curated vocabulary, shared by the screen and prints.
@immutable
class ReplayCardOptions {
  final ReplayLook look;
  final Color? artworkColor;
  final bool layered;
  final bool ornaments;
  final bool surfaceDetail;
  final bool badges;
  final bool secondaryArtwork;
  final bool tagline;
  final List<ReplayMetric> metrics;
  final Alignment photoAlignment;

  const ReplayCardOptions({
    this.look = ReplayLook.signal,
    this.artworkColor,
    this.layered = true,
    this.ornaments = true,
    this.surfaceDetail = true,
    this.badges = true,
    this.secondaryArtwork = true,
    this.tagline = true,
    this.metrics = const [
      ReplayMetric.trackTime,
      ReplayMetric.songs,
      ReplayMetric.artists,
    ],
    this.photoAlignment = Alignment.center,
  });

  ReplayCardOptions copyWith({
    ReplayLook? look,
    Color? artworkColor,
    bool? layered,
    bool? ornaments,
    bool? surfaceDetail,
    bool? badges,
    bool? secondaryArtwork,
    bool? tagline,
    List<ReplayMetric>? metrics,
    Alignment? photoAlignment,
  }) => ReplayCardOptions(
    look: look ?? this.look,
    artworkColor: artworkColor ?? this.artworkColor,
    layered: layered ?? this.layered,
    ornaments: ornaments ?? this.ornaments,
    surfaceDetail: surfaceDetail ?? this.surfaceDetail,
    badges: badges ?? this.badges,
    secondaryArtwork: secondaryArtwork ?? this.secondaryArtwork,
    tagline: tagline ?? this.tagline,
    metrics: metrics == null
        ? this.metrics
        : List.unmodifiable(metrics.toSet().take(3)),
    photoAlignment: photoAlignment ?? this.photoAlignment,
  );
}

enum ReplayCardKind { overview, songs, artists, album }

@immutable
class ReplayCardPalette {
  final Color background;
  final Color foreground;
  final Color secondary;
  final Color accent;

  const ReplayCardPalette._(
    this.background,
    this.foreground,
    this.secondary,
    this.accent,
  );

  factory ReplayCardPalette.resolve(
    ReplayCardOptions options,
    ReplayCardKind kind, {
    bool photo = false,
  }) {
    Color background;
    Color accent;
    if (photo) {
      background = ReplayStyle.ink;
      accent = ReplayStyle.acid;
    } else if (options.look == ReplayLook.artwork &&
        options.artworkColor != null) {
      final sampled = HSLColor.fromColor(options.artworkColor!);
      final primary = sampled
          .withSaturation(sampled.saturation.clamp(0.35, 0.75))
          .withLightness(sampled.lightness.clamp(0.38, 0.62))
          .toColor();
      background = switch (kind) {
        ReplayCardKind.overview => primary,
        ReplayCardKind.artists => Color.lerp(primary, ReplayStyle.paper, 0.68)!,
        _ => Color.lerp(ReplayStyle.ink, primary, 0.12)!,
      };
      accent = Color.lerp(primary, ReplayStyle.paper, 0.65)!;
    } else if (options.look == ReplayLook.night) {
      background = ReplayStyle.ink;
      accent = kind == ReplayCardKind.songs
          ? ReplayStyle.signal
          : ReplayStyle.acid;
    } else {
      background = switch (kind) {
        ReplayCardKind.overview => ReplayStyle.signal,
        ReplayCardKind.artists => ReplayStyle.acid,
        _ => ReplayStyle.ink,
      };
      accent = kind == ReplayCardKind.songs
          ? ReplayStyle.signal
          : ReplayStyle.acid;
    }
    // Choose contrast from luminance, not an assumed 'bright' hue. This also
    // covers arbitrary album colors without exposing unreadable combinations.
    final luminance = background.computeLuminance();
    final darkContrast = (luminance + 0.05) / 0.05;
    final lightContrast = 1.05 / (luminance + 0.05);
    final foreground = darkContrast >= lightContrast
        ? Colors.black
        : Colors.white;
    var secondary = Color.lerp(background, foreground, 0.82)!;
    if (contrast(background, secondary) < 4.5) secondary = foreground;
    if (contrast(background, accent) < 3) accent = foreground;
    return ReplayCardPalette._(background, foreground, secondary, accent);
  }

  Color get rule => Color.lerp(background, foreground, 0.22)!;
  bool get dark => foreground == Colors.white;

  /// Ink gets a slight lift against the route backdrop. Mid-tone artwork
  /// fields shade away from their text to preserve contrast.
  Color get shadedBackground => Color.lerp(
    background,
    background.computeLuminance() < 0.03
        ? Colors.white
        : dark
        ? Colors.black
        : Colors.white,
    background.computeLuminance() < 0.03 ? 0.03 : 0.045,
  )!;

  static double contrast(Color a, Color b) {
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    return first > second
        ? (first + 0.05) / (second + 0.05)
        : (second + 0.05) / (first + 0.05);
  }
}
