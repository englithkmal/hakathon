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
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../../data/models/monthly_summary_model.dart';
import '../providers/monthly_summaries_provider.dart';
import '../widgets/allocate_surplus_sheet.dart';

/// Detail view for a single monthly summary keyed by `(year, month)`.
class MonthlySummaryDetailScreen extends ConsumerWidget {
  const MonthlySummaryDetailScreen({
    super.key,
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lang = ref.watch(localeProvider).languageCode;
    final key = MonthlySummaryKey(year: year, month: month);
    final asyncSummary = ref.watch(monthlySummaryProvider(key));
    final monthLabel =
        DateFormat.yMMMM(lang).format(DateTime(year, month, 1));

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
          monthLabel,
          style: AppTextStyles.headlineSm(color: scheme.onSurface)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: asyncSummary.when(
        data: (summary) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthlySummaryProvider(key));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.mobileMargin,
              AppSpacing.md,
              AppSpacing.mobileMargin,
              MediaQuery.paddingOf(context).bottom + AppSpacing.xl + 80,
            ),
            children: [
              _TotalsCard(summary: summary),
              if (summary.budget.exists) ...[
                const SizedBox(height: AppSpacing.md),
                _BudgetAdherenceCard(summary: summary),
              ],
              const SizedBox(height: AppSpacing.md),
              _SurplusCard(summary: summary),
              if (summary.topCategories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _TopCategoriesSection(
                  summary: summary,
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
                  context.tr(AppStrings.monthlySummariesLoadFailed),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(monthlySummaryProvider(key)),
                  child: Text(context.tr(AppStrings.commonRetry)),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: asyncSummary.maybeWhen(
        data: (s) => s.hasUnallocatedSurplus
            ? FloatingActionButton.extended(
                onPressed: () async {
                  await showAllocateSurplusSheet(context, s);
                  // Provider already invalidated inside the notifier;
                  // nothing else to do here.
                },
                icon: const Icon(Icons.savings_rounded),
                label: Text(
                  context.tr(AppStrings.monthlySummariesAllocateCta),
                ),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

// ─────────────────────────── Cards ───────────────────────────

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.summary});

  final MonthlySummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          _TotalRow(
            label: context.tr(AppStrings.monthlySummariesIncome),
            value: summary.totalIncome,
            currency: summary.currency,
            color: AppColors.green700,
          ),
          const Divider(height: AppSpacing.lg),
          _TotalRow(
            label: context.tr(AppStrings.monthlySummariesExpenses),
            value: summary.totalExpenses,
            currency: summary.currency,
            color: scheme.error,
          ),
          const Divider(height: AppSpacing.lg),
          _TotalRow(
            label: context.tr(AppStrings.monthlySummariesSavings),
            value: summary.totalGoalDeposits,
            currency: summary.currency,
            color: AppColors.teal700,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
  });

  final String label;
  final double value;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMd(color: scheme.onSurface),
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            '${kHomeMoneyFormat.format(value)} $currency',
            style: AppTextStyles.headlineSm(color: color)
                .copyWith(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class _SurplusCard extends StatelessWidget {
  const _SurplusCard({required this.summary});

  final MonthlySummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final available = summary.unallocatedRemaining;
    final accentBg = available > 0
        ? AppColors.amber100
        : scheme.surfaceContainerHigh;
    final accentFg =
        available > 0 ? AppColors.amber700 : scheme.onSurfaceVariant;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(AppStrings.monthlySummariesSurplus),
                  style: AppTextStyles.labelSm(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              _AllocationStatusPill(status: summary.allocationStatus),
            ],
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${kHomeMoneyFormat.format(summary.unallocatedSavings)} ${summary.currency}',
                style: AppTextStyles.headlineMd(color: scheme.primary)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: context.tr(
                    AppStrings.monthlySummariesAllocatedSurplus,
                  ),
                  value: kHomeMoneyFormat.format(summary.allocatedAmount),
                  currency: summary.currency,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          AppStrings.monthlySummariesUnallocatedSurplus,
                        ),
                        style: AppTextStyles.labelSm(color: accentFg),
                      ),
                      const SizedBox(height: 2),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${kHomeMoneyFormat.format(available)} ${summary.currency}',
                          style: AppTextStyles.bodyMd(color: accentFg)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.currency,
  });

  final String label;
  final String value;
  final String currency;

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
            child: Text(
              '$value $currency',
              style: AppTextStyles.bodyMd(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill that surfaces `allocation.status` next to the surplus headline
/// (`unallocated`, `partially_allocated`, `fully_allocated`). The
/// styling roughly maps to "amber → warning" / "primary → in progress"
/// / "green → done".
class _AllocationStatusPill extends StatelessWidget {
  const _AllocationStatusPill({required this.status});

  final MonthlySummaryAllocationStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case MonthlySummaryAllocationStatus.fullyAllocated:
        bg = AppColors.green100;
        fg = AppColors.green700;
        label = context.tr(AppStrings.monthlyAllocationFully);
        break;
      case MonthlySummaryAllocationStatus.partiallyAllocated:
        bg = scheme.primary.withValues(alpha: 0.12);
        fg = scheme.primary;
        label = context.tr(AppStrings.monthlyAllocationPartial);
        break;
      case MonthlySummaryAllocationStatus.unallocated:
        bg = AppColors.amber100;
        fg = AppColors.amber700;
        label = context.tr(AppStrings.monthlyAllocationNone);
        break;
      case MonthlySummaryAllocationStatus.unknown:
        return const SizedBox.shrink();
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
      child: Text(
        label,
        style: AppTextStyles.labelSm(color: fg)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BudgetAdherenceCard extends StatelessWidget {
  const _BudgetAdherenceCard({required this.summary});

  final MonthlySummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = summary.budget.totalAmount ?? 0;
    final spent = summary.budget.totalSpent ?? 0;
    final pct = (summary.budget.adherencePct ?? 0) / 100;
    final progress = pct.clamp(0.0, 1.5);
    // Bar colour mirrors the "good / amber / over" semantics used on
    // the budget overview card so the user reads consistent signals.
    final Color barColor;
    if (progress > 1) {
      barColor = scheme.error;
    } else if (progress >= 0.8) {
      barColor = AppColors.amber500;
    } else {
      barColor = scheme.primary;
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
          Text(
            context.tr(AppStrings.monthlyBudgetAdherence),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  scheme.outlineVariant.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${kHomeMoneyFormat.format(spent)} / ${kHomeMoneyFormat.format(total)} ${summary.currency}',
                    style:
                        AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              if (summary.budget.adherencePct != null)
                Text(
                  '${summary.budget.adherencePct!.toStringAsFixed(1)}%',
                  style: AppTextStyles.bodyMd(color: barColor)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Top categories ───────────────────────────

class _TopCategoriesSection extends StatelessWidget {
  const _TopCategoriesSection({
    required this.summary,
    required this.languageCode,
  });

  final MonthlySummaryModel summary;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(AppStrings.monthlyTopCategoriesTitle),
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
              for (var i = 0; i < summary.topCategories.length; i++) ...[
                _TopCategoryRow(
                  cat: summary.topCategories[i],
                  currency: summary.currency,
                  languageCode: languageCode,
                ),
                if (i < summary.topCategories.length - 1)
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

class _TopCategoryRow extends StatelessWidget {
  const _TopCategoryRow({
    required this.cat,
    required this.currency,
    required this.languageCode,
  });

  final MonthlySummaryTopCategory cat;
  final String currency;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  color: scheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  // The summary endpoint doesn't ship per-category
                  // icons today, so fall back to the generic fallback
                  // category glyph (matches `categoryIconFor('')`).
                  categoryIconFor(''),
                  size: 18,
                  color: scheme.primary,
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
                        params: {'count': cat.count.toString()},
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
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              AppStrings.insightsExpenseCategoryShare,
              params: {'percent': cat.percentage.toStringAsFixed(1)},
            ),
            style: AppTextStyles.labelSm(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
