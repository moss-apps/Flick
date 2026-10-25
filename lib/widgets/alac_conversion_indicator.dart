import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/providers/alac_converter_provider.dart';
import 'package:flick/src/rust/api/alac_converter_api.dart' as alac_api;
import 'package:flick/l10n/l10n.dart';

/// Widget that shows ALAC conversion status
class AlacConversionIndicator extends ConsumerWidget {
  final String filePath;
  final Widget child;

  const AlacConversionIndicator({
    super.key,
    required this.filePath,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversionState = ref.watch(alacConversionProvider);
    final progress = conversionState[filePath];

    if (progress == null || !progress.isConverting) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    l10n.convertingAudio,
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Badge showing ALAC format indicator
class AlacFormatBadge extends ConsumerWidget {
  final String filePath;

  const AlacFormatBadge({super.key, required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(alacMetadataProvider(filePath));

    return metadata.when(
      data: (alac_api.AlacAudioMetadata? meta) {
        if (meta == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.purple),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.high_quality, size: 16, color: Colors.purple),
              const SizedBox(width: 4),
              Text(
                l10n.alacBit(meta.bitDepth),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Detailed ALAC metadata display
class AlacMetadataCard extends ConsumerWidget {
  final String filePath;

  const AlacMetadataCard({super.key, required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(alacMetadataProvider(filePath));

    return metadata.when(
      data: (alac_api.AlacAudioMetadata? meta) {
        if (meta == null) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(l10n.notAnAlacFile),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.audiotrack, color: Colors.purple),
                    SizedBox(width: 8),
                    Text(
                      l10n.alacAudio,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                _buildMetadataRow(l10n.sampleRate2, l10n.hz6(meta.sampleRate)),
                _buildMetadataRow(l10n.bitDepth2, '${meta.bitDepth}-bit'),
                _buildMetadataRow(l10n.channels, '${meta.channels}'),
                _buildMetadataRow(
                  l10n.duration,
                  '${meta.durationSeconds.toStringAsFixed(2)}s',
                ),
                _buildMetadataRow(l10n.samples, meta.durationSamples.toString()),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.losslessQualityPreservedDuringConversion,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.error(error)),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Snackbar helper for conversion notifications
class AlacConversionNotifications {
  static void showConversionStarted(BuildContext context, String fileName) {
    ScaffoldMessenger.of(context).showFlickSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.englishForFilipino.convertingToWav(fileName))),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showConversionComplete(BuildContext context, String fileName) {
    ScaffoldMessenger.of(context).showFlickSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.englishForFilipino.convertedSuccessfully(fileName))),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showConversionError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showFlickSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.englishForFilipino.conversionFailed(error))),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
