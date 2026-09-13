import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/providers/detail_description_provider.dart';

/// Description line under the action buttons on detail screens. Hidden until
/// the user adds a description from the more sheet.
class DetailDescription extends ConsumerWidget {
  final String descriptionKey;

  const DetailDescription({super.key, required this.descriptionKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(detailDescriptionProvider(descriptionKey));
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingSm,
        AppConstants.spacingLg,
        0,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}
