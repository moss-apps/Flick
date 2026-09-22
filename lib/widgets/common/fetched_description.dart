import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';

/// Read-only collapsible text fetched from an online source, such as an
/// artist biography or album notes. Coexists with the user-authored
/// [DetailDescription] without touching its storage.
class FetchedDescription extends StatefulWidget {
  final String text;
  final String sourceLabel;
  final int collapsedLines;

  const FetchedDescription({
    super.key,
    required this.text,
    this.sourceLabel = 'Apple Music',
    this.collapsedLines = 5,
  });

  @override
  State<FetchedDescription> createState() => _FetchedDescriptionState();
}

class _FetchedDescriptionState extends State<FetchedDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingXs,
        AppConstants.spacingLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: _expanded ? null : widget.collapsedLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.adaptiveTextSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? 'Show less' : 'Show more'),
              ),
              const Spacer(),
              Text(
                'From ${widget.sourceLabel}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
