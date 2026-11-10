import 'package:flutter/widgets.dart';
import 'package:flick/services/artwork_gate.dart';
import 'package:flick/services/orbit_card_blur_image.dart';

/// Displays a cached blur overlay, without a live filter or gradient mask.
class OrbitCardBlur extends StatefulWidget {
  const OrbitCardBlur({super.key, this.imagePath, this.audioSourcePath});

  final String? imagePath;
  final String? audioSourcePath;

  @override
  State<OrbitCardBlur> createState() => _OrbitCardBlurState();
}

class _OrbitCardBlurState extends State<OrbitCardBlur> {
  String? _resolvedPath;
  int _request = 0;
  bool _deferred = false;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant OrbitCardBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.audioSourcePath != widget.audioSourcePath) {
      _request++;
      _loadArtwork();
    }
  }

  void _loadArtwork() {
    // A prewarmed card can use its cached texture on its very first frame,
    // including while the extraction gate is held during a fling.
    _resolvedPath = OrbitCardBlurArtwork.cachedPath(
      imagePath: widget.imagePath,
      audioSourcePath: widget.audioSourcePath,
    );
    if (_resolvedPath == null) _resolveArtwork();
  }

  Future<void> _resolveArtwork() async {
    final request = ++_request;
    final path = widget.imagePath;
    final audioSourcePath = widget.audioSourcePath;
    try {
      var resolved = await OrbitCardBlurArtwork.resolveLocalPath(
        imagePath: path,
        audioSourcePath: audioSourcePath,
      );
      if (!mounted || request != _request) return;
      // Existing covers never wait for scrolling to stop. Only genuinely
      // missing artwork still uses the shared, expensive-extraction gate.
      if (resolved == null) {
        if (audioSourcePath == null || audioSourcePath.isEmpty) return;
        if (artworkExtractionPaused) {
          if (!_deferred) {
            _deferred = true;
            enqueueArtworkResolver(() {
              _deferred = false;
              if (mounted) _resolveArtwork();
            });
          }
          return;
        }
        resolved = await OrbitCardBlurArtwork.resolvePath(
          imagePath: path,
          audioSourcePath: audioSourcePath,
        );
      }
      if (!mounted || request != _request || resolved == _resolvedPath) return;
      setState(() => _resolvedPath = resolved);
    } catch (_) {
      // The sharp artwork and readability scrim remain usable on any failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _resolvedPath;
    // Baking supports local files only. Network covers normally resolve to a
    // disk-cached file; if a remote URL reaches here, keep the sharp artwork
    // and scrim rather than attempting a file decode every frame.
    if (path == null || path.startsWith('http')) {
      return const SizedBox.expand();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = constraints.biggest;
        if (!cardSize.isFinite || cardSize.isEmpty) {
          return const SizedBox.expand();
        }
        return Image(
          image: OrbitCardBlurImage(path: path, cardSize: cardSize),
          fit: BoxFit.fill,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) {
            OrbitCardBlurArtwork.forget(
              imagePath: widget.imagePath,
              audioSourcePath: widget.audioSourcePath,
            );
            return const SizedBox.expand();
          },
        );
      },
    );
  }
}
