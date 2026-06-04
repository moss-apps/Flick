import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RatingButton extends StatefulWidget {
  final int currentRating;
  final ValueChanged<int> onRatingChanged;
  final double iconSize;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? albumColor;
  final double accentBlend;
  final Color inactiveBg;
  final Color inactiveBorder;

  const RatingButton({
    super.key,
    required this.currentRating,
    required this.onRatingChanged,
    required this.iconSize,
    required this.padding,
    required this.borderRadius,
    this.albumColor,
    this.accentBlend = 0,
    required this.inactiveBg,
    required this.inactiveBorder,
  });

  @override
  State<RatingButton> createState() => _RatingButtonState();
}

class _RatingButtonState extends State<RatingButton>
    with SingleTickerProviderStateMixin {
  bool _isShowingStars = false;
  int _hoveredStar = 0;
  late AnimationController _starsController;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _starsController.dispose();
    super.dispose();
  }

  void _showStars() {
    if (_isShowingStars) return;
    setState(() {
      _isShowingStars = true;
      _hoveredStar = 0;
    });
    _starsController.forward();
  }

  void _hideStars() {
    if (!_isShowingStars) return;
    _starsController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isShowingStars = false;
          _hoveredStar = 0;
        });
      }
    });
  }

  Color _activeColor() {
    if (widget.albumColor != null && widget.accentBlend > 0) {
      final hsl = HSLColor.fromColor(widget.albumColor!);
      return hsl
          .withSaturation((hsl.saturation * 0.7).clamp(0.3, 0.8))
          .withLightness(0.65)
          .toColor();
    }
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    if (_isShowingStars) {
      return _buildStarOverlay();
    }
    return _buildIconButton();
  }

  Widget _buildIconButton() {
    final rating = widget.currentRating;
    final active = rating > 0;
    final bgColor = active
        ? _activeColor().withValues(alpha: 0.28)
        : widget.inactiveBg;
    final icon = active ? Icons.star : LucideIcons.star;

    return GestureDetector(
      onLongPress: _showStars,
      onTap: () {
        if (rating > 0) {
          widget.onRatingChanged(0);
        } else {
          _showStars();
        }
      },
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: active
              ? Border.all(color: _activeColor().withValues(alpha: 0.45))
              : Border.all(color: widget.inactiveBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.96), size: widget.iconSize),
            if (rating > 0) ...[
              SizedBox(width: widget.iconSize * 0.2),
              Text(
                '$rating',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: widget.iconSize * 0.6,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.96),
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStarOverlay() {
    final activeColor = _activeColor();

    return GestureDetector(
      onLongPressEnd: (_) => _hideStars(),
      onVerticalDragEnd: (_) => _hideStars(),
      onHorizontalDragEnd: (_) => _hideStars(),
      child: AnimatedBuilder(
        animation: _starsController,
        builder: (context, child) {
          return Container(
            padding: widget.padding + const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: activeColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                final delay = i * 0.08;
                final starProgress = (_starsController.value - delay)
                    .clamp(0.0, 1.0);
                final easedProgress = Curves.easeOutBack.transform(starProgress).clamp(0.001, double.infinity);
                final isFilled = starIndex <= (widget.currentRating);
                final isHovered = _hoveredStar > 0 && starIndex <= _hoveredStar;

                return GestureDetector(
                  onTap: () {
                    widget.onRatingChanged(starIndex);
                    _hideStars();
                  },
                  onTapDown: (_) {
                    setState(() => _hoveredStar = starIndex);
                  },
                  onTapUp: (_) {
                    setState(() => _hoveredStar = 0);
                  },
                  onTapCancel: () {
                    setState(() => _hoveredStar = 0);
                  },
                  onVerticalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final localPos = box.globalToLocal(details.globalPosition);
                    final starWidth = box.size.width / 5;
                    final hovered = ((localPos.dx / starWidth).ceil()).clamp(0, 5);
                    if (hovered != _hoveredStar) {
                      setState(() => _hoveredStar = hovered);
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final localPos = box.globalToLocal(details.globalPosition);
                    final starWidth = box.size.width / 5;
                    final hovered = ((localPos.dx / starWidth).ceil()).clamp(0, 5);
                    if (hovered != _hoveredStar) {
                      setState(() => _hoveredStar = hovered);
                    }
                  },
                  child: Transform.scale(
                    scale: easedProgress,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.iconSize * 0.08,
                      ),
                      child: Icon(
                        (isFilled || isHovered) ? Icons.star : Icons.star_border,
                        color: (isFilled || isHovered)
                            ? Colors.amber.shade400
                            : Colors.white.withValues(alpha: 0.4),
                        size: widget.iconSize * 0.85,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}