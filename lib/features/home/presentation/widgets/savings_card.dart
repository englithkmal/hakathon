import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/dashboard_model.dart';
import '../utils/home_money.dart';
import 'home_insight_tile.dart';

/// Dark green savings card. Shows the topmost active goal with its
/// progress and remaining amount. Falls back to a friendly "add a goal"
/// CTA when the user has no goals yet.
class HomeSavingsCard extends StatelessWidget {
  const HomeSavingsCard({
    super.key,
    required this.goals,
    required this.savingsOverview,
    required this.currency,
  });

  final List<DashboardGoal> goals;
  final DashboardSavingsOverview savingsOverview;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final goal = goals.isNotEmpty ? goals.first : null;
    final progress = goal?.progress ?? savingsOverview.progress;
    final remaining = goal?.remaining ?? savingsOverview.remaining;
    final pct = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.savings_rounded,
                  size: 18,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(AppStrings.homeSavingsLabel),
                      style: AppTextStyles.labelSm(
                        color:
                            scheme.onPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal?.title.isNotEmpty == true
                          ? goal!.title
                          : context.tr(AppStrings.homeNoActiveGoal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMd(
                        color: scheme.onPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (goal != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '$pct%',
                    style: AppTextStyles.bodyMd(
                      color: scheme.onPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: scheme.onPrimary.withValues(alpha: 0.18),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: Container(color: scheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (goal != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(
                AppStrings.homeSavingsRemaining,
                params: {
                  'amount': '${formatHomeMoney(remaining, currency)} '
                      '${goal.currency.isNotEmpty ? goal.currency : currency}',
                },
              ),
              style: AppTextStyles.labelMd(
                color: scheme.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tries to use the goal's icon key; falls back to a piggy-bank when
/// nothing matches. Re-exported for convenience.
IconData homeSavingsCardIcon(String iconKey) =>
    iconKey.isEmpty ? Icons.savings_rounded : homeGoalIcon(iconKey);
