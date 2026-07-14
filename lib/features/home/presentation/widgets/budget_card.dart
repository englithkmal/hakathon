import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/dashboard_model.dart';
import '../utils/home_budget_math.dart';

/// Slim budget card for the new home screen. Shows the wallet icon, the
/// active-status pill, a progress bar, and a hint sentence with the used
/// percentage.
class HomeBudgetCard extends StatelessWidget {
  const HomeBudgetCard({super.key, required this.dashboard});

  final DashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spent = homeBudgetSpent(dashboard);
    final total = homeBudgetTotal(dashboard);
    final progress = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
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
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(AppStrings.homeBudgetLabel),
                      style: AppTextStyles.labelSm(color: scheme.outline),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(AppStrings.homeBudgetActiveStatus),
                      style: AppTextStyles.bodySm(color: scheme.onSurface)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
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
                  Container(color: scheme.surfaceContainerHigh),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: [scheme.primary, scheme.tertiary],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(
              AppStrings.homeBudgetUsageHint,
              params: {'pct': '$pct'},
            ),
            style: AppTextStyles.labelMd(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
