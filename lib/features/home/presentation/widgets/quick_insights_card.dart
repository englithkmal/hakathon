import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../../data/models/dashboard_model.dart';
import '../utils/home_money.dart' show kHomeMoneyFormat;

/// "وين راحت فلوسك" — top 3 expense categories of the current month
/// rendered as horizontal rows with the category icon, name, total
/// spent, percentage of monthly expenses and how many transactions
/// contributed to it.
///
/// Data source: `dashboard.quick_insights` (already top-3 from the
/// backend). The card hides itself entirely when the list is empty so
/// the home layout doesn't show a blank section on first launch.
class HomeQuickInsightsCard extends StatelessWidget {
  const HomeQuickInsightsCard({
    super.key,
    required this.insights,
    required this.languageCode,
    required this.currency,
  });

  final List<DashboardQuickInsight> insights;
  final String languageCode;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          _Header(scheme: scheme),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < insights.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            _InsightRow(
              insight: insights[i],
              languageCode: languageCode,
              currency: currency,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(AppStrings.homeQuickInsightsTitle),
                style: AppTextStyles.headlineMd(color: scheme.onSurface)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr(AppStrings.homeQuickInsightsSubtitle),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.insights_rounded,
            size: 18,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.insight,
    required this.languageCode,
    required this.currency,
  });

  final DashboardQuickInsight insight;
  final String languageCode;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(insight.category.color) ?? scheme.primary;
    final pct = insight.percentage.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                categoryIconFor(
                  insight.category.icon.isNotEmpty
                      ? insight.category.icon
                      : insight.category.slug,
                ),
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.category.displayName(languageCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMd(color: scheme.onSurface)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(
                      AppStrings.homeQuickInsightsTxCount,
                      params: {'count': '${insight.count}'},
                    ),
                    style: AppTextStyles.labelSm(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currency,
                          style: AppTextStyles.labelSm(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          kHomeMoneyFormat.format(insight.total),
                          style: AppTextStyles.bodyMd(color: scheme.onSurface)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                _PercentChip(percent: pct, accent: accent),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: scheme.surfaceContainerHigh),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: pct / 100,
                    heightFactor: 1,
                    child: Container(color: accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PercentChip extends StatelessWidget {
  const _PercentChip({required this.percent, required this.accent});

  final double percent;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          '${percent.toStringAsFixed(percent >= 10 ? 0 : 1)}%',
          style: AppTextStyles.labelSm(color: accent).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
