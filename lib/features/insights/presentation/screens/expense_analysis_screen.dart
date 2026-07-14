import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../home/presentation/utils/home_money.dart';
import '../../../period/presentation/widgets/latest_budget_banner.dart';
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../../data/models/expense_analysis_model.dart';
import '../providers/expense_analysis_provider.dart';

/// Top-level screen for `GET /insights/expense-analysis`.
///
/// Layout (top → bottom):
///   AppBar          — back arrow + period title
///   LatestBudgetBanner (when applicable)
///   Summary card    — total spent, MoM delta, daily avg, txn count
///   Categories list — per-category share, MoM, txn count
class ExpenseAnalysisScreen extends ConsumerWidget {
  const ExpenseAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lang = ref.watch(localeProvider).languageCode;
    final asyncAnalysis = ref.watch(expenseAnalysisProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.tr(AppStrings.insightsExpenseTitle),
          style: AppTextStyles.headlineSm(color: scheme.onSurface)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: asyncAnalysis.when(
        data: (analysis) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(expenseAnalysisProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.mobileMargin,
              AppSpacing.md,
              AppSpacing.mobileMargin,
              MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
            ),
            children: [
              LatestBudgetBanner(period: analysis.serverPeriod),
              _PeriodHeader(
                periodStart: analysis.serverPeriod.periodStart,
                fallbackMonth: analysis.serverPeriod.month,
                fallbackYear: analysis.serverPeriod.year,
                languageCode: lang,
              ),
              const SizedBox(height: AppSpacing.md),
              if (analysis.isEmpty)
                const _EmptyCard()
              else ...[
                _SummaryCard(analysis: analysis),
                const SizedBox(height: AppSpacing.lg),
                _CategoriesSection(
                  analysis: analysis,
                  languageCode: lang,
                ),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.mobileMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(AppStrings.insightsExpenseLoadFailed),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(expenseAnalysisProvider),
                  child: Text(context.tr(AppStrings.commonRetry)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.periodStart,
    required this.fallbackMonth,
    required this.fallbackYear,
    required this.languageCode,
  });

  final String periodStart;
  final int fallbackMonth;
  final int fallbackYear;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    DateTime? date;
    if (periodStart.isNotEmpty) {
      date = DateTime.tryParse(periodStart);
    }
    date ??= DateTime(
      fallbackYear > 0 ? fallbackYear : DateTime.now().year,
      fallbackMonth >= 1 && fallbackMonth <= 12
          ? fallbackMonth
          : DateTime.now().month,
    );
    return Text(
      DateFormat.yMMMM(languageCode).format(date),
      style: AppTextStyles.headlineMd(color: scheme.onSurface)
          .copyWith(fontWeight: FontWeight.w800),
    );
  }
}

// ───────────────────────────── Summary ─────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.analysis});

  final ExpenseAnalysisModel analysis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = analysis.summary;
    final mom = summary.momChangePercent;
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
          Text(
            context.tr(AppStrings.insightsExpenseTotalSpent),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${kHomeMoneyFormat.format(summary.totalSpent)} ${analysis.currency}',
                style: AppTextStyles.headlineMd(color: scheme.error)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (mom != null) _MomChip(percent: mom),
          if (summary.topCategoryName.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(
                AppStrings.insightsExpenseTopCategory,
                params: {'name': summary.topCategoryName},
              ),
              style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: context.tr(
                    AppStrings.insightsExpenseAvgPerTransaction,
                  ),
                  value: kHomeMoneyFormat.format(summary.avgPerTransaction),
                  suffix: analysis.currency,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SummaryMetric(
                  label: context.tr(AppStrings.insightsExpenseDailyAverage),
                  value: kHomeMoneyFormat.format(
                    _resolveDailyAverage(summary.dailyAverage,
                        summary.totalSpent, analysis),
                  ),
                  suffix: analysis.currency,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(
              AppStrings.insightsExpenseTransactions,
              params: {'count': summary.transactionCount.toString()},
            ),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Falls back to a derived `total / days_in_period` when the server
  /// doesn't ship a precomputed `daily_average`.
  double _resolveDailyAverage(
    double serverValue,
    double total,
    ExpenseAnalysisModel analysis,
  ) {
    if (serverValue > 0) return serverValue;
    final start = analysis.serverPeriod.periodStart;
    final end = analysis.serverPeriod.periodEnd;
    final s = start.isNotEmpty ? DateTime.tryParse(start) : null;
    final e = end.isNotEmpty ? DateTime.tryParse(end) : null;
    if (s == null || e == null) return 0;
    final today = DateTime.now();
    // Use today as the upper bound while the month is still in
    // progress so the average doesn't get artificially deflated by
    // unspent days at the end of the month.
    final upperBound = today.isBefore(e) ? today : e;
    final days = upperBound.difference(s).inDays + 1;
    if (days <= 0) return 0;
    return total / days;
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.suffix,
  });

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.brSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '$value $suffix',
                style: AppTextStyles.headlineSm(color: scheme.onSurface)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomChip extends StatelessWidget {
  const _MomChip({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUp = percent > 0.5;
    final isDown = percent < -0.5;
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;
    if (isUp) {
      bg = AppColors.amber100;
      fg = AppColors.amber700;
      icon = Icons.trending_up_rounded;
      label = context.tr(
        AppStrings.insightsExpenseMomUp,
        params: {'percent': percent.abs().toStringAsFixed(1)},
      );
    } else if (isDown) {
      bg = AppColors.green100;
      fg = AppColors.green700;
      icon = Icons.trending_down_rounded;
      label = context.tr(
        AppStrings.insightsExpenseMomDown,
        params: {'percent': percent.abs().toStringAsFixed(1)},
      );
    } else {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant;
      icon = Icons.trending_flat_rounded;
      label = context.tr(AppStrings.insightsExpenseMomFlat);
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSm(color: fg)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Categories ─────────────────────────────

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({
    required this.analysis,
    required this.languageCode,
  });

  final ExpenseAnalysisModel analysis;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (analysis.categories.isEmpty) return const SizedBox.shrink();
    final sorted = [...analysis.categories]
      ..sort((a, b) => b.total.compareTo(a.total));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(AppStrings.insightsExpenseCategoriesTitle),
          style: AppTextStyles.headlineSm(color: scheme.onSurface)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++) ...[
                _CategoryRow(
                  cat: sorted[i],
                  currency: analysis.currency,
                  languageCode: languageCode,
                ),
                if (i < sorted.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Divider(height: 1),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.cat,
    required this.currency,
    required this.languageCode,
  });

  final ExpenseAnalysisCategory cat;
  final String currency;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(cat.color) ?? scheme.primary;
    final progress = (cat.percentage / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Column(
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
                  categoryIconFor(cat.icon),
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.displayName(languageCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMd(color: scheme.onSurface)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                        AppStrings.insightsExpenseCategoryTxnCount,
                        params: {
                          'count': cat.transactionCount.toString(),
                        },
                      ),
                      style: AppTextStyles.labelSm(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${kHomeMoneyFormat.format(cat.total)} $currency',
                  style: AppTextStyles.bodyMd(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: scheme.outlineVariant.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                context.tr(
                  AppStrings.insightsExpenseCategoryShare,
                  params: {
                    'percent': cat.percentage.toStringAsFixed(1),
                  },
                ),
                style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (cat.momChangePercent != null)
                _CategoryMomBadge(percent: cat.momChangePercent!),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryMomBadge extends StatelessWidget {
  const _CategoryMomBadge({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUp = percent > 0.5;
    final isDown = percent < -0.5;
    final Color color;
    final IconData icon;
    if (isUp) {
      color = AppColors.amber700;
      icon = Icons.arrow_upward_rounded;
    } else if (isDown) {
      color = AppColors.green700;
      icon = Icons.arrow_downward_rounded;
    } else {
      color = scheme.onSurfaceVariant;
      icon = Icons.trending_flat_rounded;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          '${percent.abs().toStringAsFixed(1)}%',
          style: AppTextStyles.labelSm(color: color)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_rounded,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(AppStrings.insightsExpenseEmpty),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
