import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/utils/home_money.dart';
import '../../../home/presentation/widgets/home_app_bar.dart' show HomeUserAvatar;
import '../../../notifications/presentation/widgets/notifications_bell.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../../../transactions/presentation/widgets/transaction_item.dart';
import '../../data/models/budget_category_model.dart';
import '../../data/models/budget_model.dart';
import '../providers/budget_tab_provider.dart';
import '../providers/category_transactions_provider.dart';

/// Detail screen for a single budget category.
///
/// Renders:
///   - the category summary (allocated/spent/remaining + progress bar)
///   - daily-average and days-left chips
///   - the recent expense operations in this category (this month),
///     grouped by day (Today / Yesterday / explicit dates).
///
/// Source of truth:
///   - The category itself comes from [budgetTabProvider] — same data
///     the overview screen renders from, so navigating here doesn't
///     trigger a refetch.
///   - The operations come from [categoryTransactionsProvider] which
///     hits `/transactions?category_id=X&from=…&to=…`.
class BudgetCategoryDetailScreen extends ConsumerWidget {
  const BudgetCategoryDetailScreen({super.key, required this.budgetCategoryId});

  /// Pivot row id (`budget_categories.id`) — *not* the global
  /// category id. Matches `BudgetCategoryModel.id`.
  final int budgetCategoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final asyncTab = ref.watch(budgetTabProvider);
    final auth = ref.watch(authProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final lang = ref.watch(localeProvider).languageCode;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _DetailAppBar(
        user: user,
        onNotificationsTap: () => context.go(RouteNames.notificationsPath),
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(RouteNames.budgetPath),
      ),
      body: asyncTab.when(
        data: (tab) {
          final budget = tab.budget;
          final cat = budget?.categories.firstWhere(
            (c) => c.id == budgetCategoryId,
            orElse: () => _missingCategory,
          );
          if (budget == null || cat == null || cat.id == 0) {
            return _MissingState(
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(RouteNames.budgetPath),
            );
          }
          return _DetailBody(
            budget: budget,
            cat: cat,
            languageCode: lang,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.mobileMargin),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.tr(AppStrings.homeLoadFailed),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(budgetTabProvider),
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

// `firstWhere` requires a non-null fallback in the strict-null world;
// we use a zero-id sentinel and check for it on the consumer side.
final BudgetCategoryModel _missingCategory = BudgetCategoryModel(
  id: 0,
  category: BudgetCategoryRefModel.fromJson(const {}),
  allocatedAmount: 0,
  spentAmount: 0,
  remainingApi: 0,
  usagePercentage: 0,
  alertThreshold: 0,
);

// ──────────────────────────── App bar ────────────────────────────

class _DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailAppBar({
    required this.user,
    required this.onNotificationsTap,
    required this.onBack,
  });

  final dynamic user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppDimens.appBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.mobileMargin,
            ),
            child: Stack(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HomeUserAvatar(user: user),
                      const SizedBox(width: AppSpacing.sm),
                      NotificationsBell(onTap: onNotificationsTap),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    context.tr(AppStrings.budgetDetailTitle),
                    style: AppTextStyles.headlineMd(color: scheme.primary)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    onPressed: onBack,
                    // Logical "next" in RTL = back-arrow visually on
                    // the right; `arrow_forward` flips correctly when
                    // the directionality is RTL because we use the
                    // rounded variant which honours the locale arrow.
                    icon: const Icon(Icons.arrow_forward_rounded),
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Body ────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.budget,
    required this.cat,
    required this.languageCode,
  });

  final BudgetModel budget;
  final BudgetCategoryModel cat;
  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTx = ref.watch(
      categoryTransactionsProvider(
        CategoryTransactionsKey(
          categoryId: cat.category.id,
          month: budget.month,
          year: budget.year,
        ),
      ),
    );

    return RefreshIndicator(
      onRefresh: () async {
        // The detail screen is downstream of the budget tab provider,
        // so refreshing it gets the user the freshest figures *and*
        // implicitly refreshes the parent screen too.
        ref.invalidate(categoryTransactionsProvider);
        await ref.read(budgetTabProvider.notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.mobileMargin,
          AppSpacing.sm,
          AppSpacing.mobileMargin,
          MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CategorySummaryCard(
                  budget: budget,
                  cat: cat,
                  languageCode: languageCode,
                ),
                const SizedBox(height: AppSpacing.lg),
                _RecentOperationsSection(
                  asyncTx: asyncTx,
                  languageCode: languageCode,
                  onSeeAll: () =>
                      context.go(RouteNames.transactionsPath),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Summary card ────────────────────────────

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({
    required this.budget,
    required this.cat,
    required this.languageCode,
  });

  final BudgetModel budget;
  final BudgetCategoryModel cat;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(cat.category.color) ?? scheme.primary;
    final currency = budget.currency;
    final period = _formatBudgetPeriod(budget, languageCode);
    final overBudget = cat.exceeded;

    // Anchor the period to the API's `period_start` when available so
    // the "days left" calc lines up with the budget Laravel persisted
    // (also covers budgets created for a non-current month).
    final periodStart =
        budget.periodStartDate ?? DateTime(budget.year, budget.month, 1);
    final periodEnd = budget.periodEndDate ??
        DateTime(periodStart.year, periodStart.month + 1, 0);
    final daysInMonth = periodEnd.day;
    final today = DateTime.now();
    final inThisPeriod = today.year == periodStart.year &&
        today.month == periodStart.month;
    final dayOfMonth = inThisPeriod ? today.day : daysInMonth;
    final daysLeft =
        inThisPeriod ? (daysInMonth - dayOfMonth).clamp(0, daysInMonth) : 0;

    // Average daily spend so far this month. Falls back to 0 when
    // we're at the start of the month and `dayOfMonth` is 1 with no
    // spending yet — avoids divide-by-zero noise.
    final dailyAvg = dayOfMonth > 0 ? cat.spentAmount / dayOfMonth : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          // Top: title + period + icon. The edit affordance lives on
          // the budget overview now, so the header here is read-only.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cat.category.displayName(languageCode),
                    style: AppTextStyles.labelLg(color: scheme.onSurface)
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  if (period.isNotEmpty)
                    Text(
                      period,
                      style: AppTextStyles.labelSm(color: scheme.outline),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              _CategoryIconBubble(
                icon: categoryIconFor(cat.category.icon),
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Headline remaining figure (right-aligned in RTL).
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.tr(AppStrings.budgetDetailRemainingLabel),
                  style: AppTextStyles.labelSm(color: scheme.outline),
                ),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currency,
                          style: AppTextStyles.labelMd(
                            color:
                                overBudget ? scheme.error : scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          kHomeMoneyFormat.format(cat.remaining),
                          style: AppTextStyles.headlineXl(
                            color:
                                overBudget ? scheme.error : scheme.primary,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AmountLine(
            label: context.tr(AppStrings.budgetDetailSpentLabel),
            amount: cat.spentAmount,
            currency: currency,
            color: scheme.onSurface,
          ),
          const SizedBox(height: 4),
          _AmountLine(
            label: context.tr(AppStrings.budgetDetailTotalLabel),
            amount: cat.allocatedAmount,
            currency: currency,
            color: scheme.onSurface,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: cat.progress,
              minHeight: 8,
              backgroundColor: scheme.outlineVariant.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                overBudget ? scheme.error : scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: context.tr(AppStrings.budgetDetailDailyAvg),
                  valueText:
                      '${kHomeMoneyFormat.format(dailyAvg)} $currency',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  label: context.tr(AppStrings.budgetDetailDaysLeft),
                  valueText: context.tr(
                    AppStrings.budgetDetailDaysLeftValue,
                    params: {'count': '$daysLeft'},
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

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currency,
                style: AppTextStyles.labelSm(color: scheme.outline),
              ),
              const SizedBox(width: 4),
              Text(
                kHomeMoneyFormat.format(amount),
                style: AppTextStyles.bodyMd(color: color)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label:',
          style: AppTextStyles.labelMd(color: scheme.outline),
        ),
      ],
    );
  }
}

class _CategoryIconBubble extends StatelessWidget {
  const _CategoryIconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.valueText});

  final String label;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppRadius.brSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSm(color: scheme.outline),
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              valueText,
              style: AppTextStyles.bodyMd(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Recent operations ────────────────────────────

class _RecentOperationsSection extends StatelessWidget {
  const _RecentOperationsSection({
    required this.asyncTx,
    required this.languageCode,
    required this.onSeeAll,
  });

  final AsyncValue<List<TransactionModel>> asyncTx;
  final String languageCode;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                child: Text(
                  context.tr(AppStrings.budgetSeeAll),
                  style: AppTextStyles.labelSm(color: scheme.primary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const Spacer(),
            Text(
              context.tr(AppStrings.budgetDetailRecentOps),
              style: AppTextStyles.labelLg(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        asyncTx.when(
          data: (items) => _OperationsList(
            items: items,
            languageCode: languageCode,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              context.tr(AppStrings.homeLoadFailed),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(color: scheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _OperationsList extends StatelessWidget {
  const _OperationsList({required this.items, required this.languageCode});

  final List<TransactionModel> items;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          context.tr(AppStrings.budgetDetailEmpty),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final groups = _groupByDay(items);

    return Column(
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              0,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                _formatGroupLabel(context, group.day, languageCode),
                style: AppTextStyles.labelSm(color: scheme.outline),
              ),
            ),
          ),
          for (var i = 0; i < group.items.length; i++) ...[
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: TransactionItem(
                transaction: group.items[i],
                languageCode: languageCode,
                formatTime: (when) =>
                    formatTransactionTime(when, languageCode),
              ),
            ),
            if (i < group.items.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _DayGroup {
  _DayGroup(this.day, this.items);
  final DateTime day;
  final List<TransactionModel> items;
}

List<_DayGroup> _groupByDay(List<TransactionModel> items) {
  final byDay = <DateTime, List<TransactionModel>>{};
  for (final tx in items) {
    final parsed = DateTime.tryParse(tx.transactionDate)?.toLocal();
    if (parsed == null) continue;
    final key = DateTime(parsed.year, parsed.month, parsed.day);
    byDay.putIfAbsent(key, () => []).add(tx);
  }
  final entries = byDay.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  return [for (final e in entries) _DayGroup(e.key, e.value)];
}

String _formatGroupLabel(BuildContext context, DateTime day, String lang) {
  final today = DateTime.now();
  final t = DateTime(today.year, today.month, today.day);
  final yesterday = t.subtract(const Duration(days: 1));
  final dateText = DateFormat('d MMMM', lang).format(day);
  if (day == t) {
    return '${context.tr(AppStrings.budgetDetailToday)}، $dateText';
  }
  if (day == yesterday) {
    return '${context.tr(AppStrings.budgetDetailYesterday)}، $dateText';
  }
  return dateText;
}

// ──────────────────────────── Misc ────────────────────────────

class _MissingState extends StatelessWidget {
  const _MissingState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mobileMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: scheme.outline,
              size: 36,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(AppStrings.budgetCategoriesEmpty),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onBack,
              child: Text(context.tr(AppStrings.commonRetry)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Format the budget's period header. Prefers the server-provided
/// `period_start` so the label always matches what Laravel persisted
/// — falls back to the legacy `month`/`year` synthesis when older
/// payloads ship without the new fields.
String _formatBudgetPeriod(BudgetModel budget, String languageCode) {
  final start = budget.periodStartDate;
  if (start != null) {
    return DateFormat.yMMMM(languageCode).format(start);
  }
  if (budget.month < 1 || budget.month > 12) return '';
  final d = DateTime(
    budget.year > 0 ? budget.year : DateTime.now().year,
    budget.month,
  );
  return DateFormat.yMMMM(languageCode).format(d);
}
