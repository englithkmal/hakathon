import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/dashboard_model.dart';

/// "نصيحة اليوم" card — a soft greenish info card on the start side and
/// a primary CTA button on the end side.
class HomeTipOfTheDayCard extends StatelessWidget {
  const HomeTipOfTheDayCard({
    super.key,
    required this.tip,
    required this.languageCode,
    required this.onCtaTap,
  });

  final DashboardTip tip;
  final String languageCode;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!tip.exists) return const SizedBox.shrink();

    final body = tip.displayContent(languageCode);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.18),
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(AppStrings.homeTipOfTheDay),
                  style: AppTextStyles.labelSm(
                    color: scheme.primary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm(color: scheme.onSurface),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton(
            onPressed: onCtaTap,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: AppTextStyles.labelMd(color: scheme.onPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            child: Text(context.tr(AppStrings.homeTipExploreCta)),
          ),
        ],
      ),
    );
  }
}
