import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/dashboard_model.dart';
import '../utils/home_money.dart';
import '../utils/home_weekly_breakdown.dart';

/// Re-designed balance card for the new home screen. Shows:
///   - the total balance and the monthly trend chip (top, opposing sides)
///   - the month-to-date spending headline (right-aligned in RTL)
///   - a smooth line chart of cumulative spend across the month
///   - 4 weekly chips with the per-week expense amount
class HomeBalanceCard extends StatelessWidget {
  const HomeBalanceCard({
    super.key,
    required this.dashboard,
    required this.balance,
    required this.monthlyExpenses,
    required this.momPercent,
  });

  final DashboardModel dashboard;
  final double balance;
  final double monthlyExpenses;
  final double? momPercent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = dashboard.currency;
    final weekly = homeWeeklyBuckets(dashboard);
    final curve = homeMonthSpendCurve(dashboard);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topRow(context, scheme, currency),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 80,
            child: _SpendingCurve(points: curve),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          _WeeklyChips(buckets: weekly, currency: currency),
        ],
      ),
    );
  }

  /// Top block: total balance on the start side, monthly-spend block on
  /// the end side. Includes the small `+12% ↑` chip from Figma.
  Widget _topRow(BuildContext context, ColorScheme scheme, String currency) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // Label tracks the headline figure provided by the
                // dashboard screen. The total balance lives in the
                // separate card above, so we never repeat it here:
                //   - with a budget    -> "متبقي من الميزانية"
                //   - without a budget -> "الراتب الشهري"
                //                         (monthly_income from the API,
                //                         see _homeHeadlineBalance).
                context.tr(
                  dashboard.hasBudget
                      ? AppStrings.homeBudgetRemaining
                      : AppStrings.homeMonthlySalary,
                ),
                style: AppTextStyles.labelSm(color: scheme.outline),
              ),
              const SizedBox(height: AppSpacing.xs),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currency,
                      style: AppTextStyles.labelMd(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      kHomeMoneyFormat.format(balance),
                      style: AppTextStyles.headlineXl(
                        color: scheme.onSurface,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (momPercent != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _TrendChip(percent: momPercent!),
              ],
              // When there's no active budget the headline shows the
              // monthly salary; surface any extra non-salary income
              // (`summary.income`) right underneath so the user still
              // sees where the rest of `total_income` came from.
              if (!dashboard.hasBudget && dashboard.summary.income > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                _ExtraIncomeChip(
                  amount: dashboard.summary.income,
                  currency: currency,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              context.tr(AppStrings.homeMonthlyExpenses),
              style: AppTextStyles.labelSm(color: scheme.outline),
            ),
            const SizedBox(height: AppSpacing.xs),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currency,
                    style: AppTextStyles.labelMd(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    kHomeMoneyFormat.format(monthlyExpenses),
                    style: AppTextStyles.headlineMd(
                      color: scheme.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final positive = percent >= 0;
    final fg = positive ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 3),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${positive ? '+' : ''}${percent.toStringAsFixed(0)}%',
              style: AppTextStyles.labelSm(color: fg).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft pill that surfaces non-salary income recorded for the period
/// (`summary.income`). Sits underneath the salary headline so the user
/// can tell why the total income figure on the top card differs from
/// the salary shown here.
class _ExtraIncomeChip extends StatelessWidget {
  const _ExtraIncomeChip({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 14, color: fg),
          const SizedBox(width: 3),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currency,
                  style: AppTextStyles.labelSm(color: fg),
                ),
                const SizedBox(width: 3),
                Text(
                  kHomeMoneyFormat.format(amount),
                  style: AppTextStyles.labelSm(color: fg).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            context.tr(AppStrings.homeExtraIncome),
            style: AppTextStyles.labelSm(color: fg),
          ),
        ],
      ),
    );
  }
}

/// The smooth area-line behind the balance figure. We draw it ourselves
/// with `fl_chart` so it always uses the active theme colours.
class _SpendingCurve extends StatelessWidget {
  const _SpendingCurve({required this.points});

  final List<({int day, double value})> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (points.isEmpty || points.every((p) => p.value == 0)) {
      // Empty state — render a flat baseline so the card keeps the same
      // height instead of jumping around between months.
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      );
    }

    final spots = points
        .map((p) => FlSpot(p.day.toDouble(), p.value))
        .toList();

    final maxY = points
            .map((p) => p.value)
            .reduce((a, b) => a > b ? a : b) *
        1.1;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 1,
        maxX: points.last.day.toDouble(),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: scheme.primary,
            barWidth: 2.4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.22),
                  scheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4 fixed-width chips sized to `Expanded`, each one showing the week
/// label and the total expense for that week.
class _WeeklyChips extends StatelessWidget {
  const _WeeklyChips({required this.buckets, required this.currency});

  final List<HomeWeeklyBucket> buckets;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < buckets.length; i++) ...[
          Expanded(child: _WeekCell(bucket: buckets[i], currency: currency)),
          if (i < buckets.length - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({required this.bucket, required this.currency});

  final HomeWeeklyBucket bucket;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            AppStrings.homeWeekN,
            params: {'n': '${bucket.weekIndex}'},
          ),
          style: AppTextStyles.labelSm(color: scheme.outline),
        ),
        const SizedBox(height: 2),
        // FittedBox.scaleDown shrinks the currency + amount row when the
        // four chips can't share enough horizontal space (e.g. on narrow
        // phones with USD-style 3-letter codes and a 4-digit weekly
        // total). Keeps the whole figure visible without overflow.
        Directionality(
          textDirection: TextDirection.ltr,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currency,
                  style: AppTextStyles.labelSm(color: scheme.outline),
                ),
                const SizedBox(width: 3),
                Text(
                  kHomeMoneyFormat.format(bucket.amount),
                  style: AppTextStyles.bodyMd(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
