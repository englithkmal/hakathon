import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_currency_provider.dart';
import '../../../home/presentation/utils/home_money.dart';
import '../../../home/presentation/widgets/home_app_bar.dart' show HomeUserAvatar;
import '../../../notifications/presentation/widgets/notifications_bell.dart';
import '../../../period/presentation/widgets/latest_budget_banner.dart';
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../../data/data_sources/budget_remote_data_source.dart';
import '../../data/models/budget_category_model.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/saving_goal_model.dart';
import '../providers/budget_tab_provider.dart';
import '../utils/goal_pace_palette.dart';

/// Top-level "Saver" tab.
///
/// Source of truth: [budgetTabProvider] which calls `/budgets/current`
/// and `/saving-goals?status=active` in parallel. The dashboard
/// endpoint is *not* used here — the dedicated endpoints return fully
/// hydrated category rows and respect `Accept-Language`.
///
/// Layout (top to bottom):
///   AppBar       — avatar / bell / centred title
///   Overview     — header + month + dark-green summary card
///   Categories   — header + budget category rows
///   Saving goals — header + add CTA + 2-column goals grid
class BudgetOverviewScreen extends ConsumerWidget {
  const BudgetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final asyncTab = ref.watch(budgetTabProvider);
    final auth = ref.watch(authProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final lang = ref.watch(localeProvider).languageCode;
    final userCurrency = ref.watch(userCurrencyProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _BudgetAppBar(
        user: user,
        onNotificationsTap: () => context.go(RouteNames.notificationsPath),
        onMonthlySummariesTap: () =>
            context.push(RouteNames.monthlySummariesPath),
        onInsightsTap: () =>
            context.push(RouteNames.insightsExpensePath),
        onHistoryTap: () =>
            context.push(RouteNames.budgetsHistoryPath),
      ),
      body: asyncTab.when(
        data: (tab) => RefreshIndicator(
          onRefresh: () => ref.read(budgetTabProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.mobileMargin,
              AppSpacing.sm,
              AppSpacing.mobileMargin,
              MediaQuery.paddingOf(context).bottom + AppSpacing.xl + 80,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimens.maxContentWidth,
                ),
                child: _BudgetBody(
                  tab: tab,
                  languageCode: lang,
                  userCurrency: userCurrency,
                ),
              ),
            ),
          ),
        ),
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

class _BudgetBody extends StatelessWidget {
  const _BudgetBody({
    required this.tab,
    required this.languageCode,
    required this.userCurrency,
  });

  final BudgetTabData tab;
  final String languageCode;

  /// Currency to use when no budget exists yet. Existing budgets and
  /// goals always render with their own `currency` field; this is
  /// just the fallback for new resources / empty states.
  final String userCurrency;

  @override
  Widget build(BuildContext context) {
    final budget = tab.budget;
    final period = budget != null
        ? _formatBudgetPeriod(budget, languageCode)
        : _formatPeriod(
            DateTime.now().month,
            DateTime.now().year,
            languageCode,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Spec: read meta.period.source — when the server fell back to
        // the user's latest active budget month, surface a banner so
        // they understand the displayed month differs from the server's
        // calendar month.
        LatestBudgetBanner(period: tab.serverPeriod),
        _SectionHeader(
          title: context.tr(AppStrings.budgetOverviewTitle),
          trailing: Text(
            period,
            style: AppTextStyles.labelSm(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        budget != null
            ? _OverviewSummaryCard(budget: budget)
            : const _OverviewEmptyState(),
        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(
          title: context.tr(AppStrings.budgetCategoriesTitle),
          trailing: _LinkText(
            label: context.tr(AppStrings.budgetAddCategory),
            onTap: () => context.push(RouteNames.budgetAddCategoryPath),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _BudgetCategoriesList(
          categories: budget?.categories ?? const [],
          currency: (budget?.currency.isNotEmpty ?? false)
              ? budget!.currency
              : userCurrency,
          languageCode: languageCode,
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(
          title: context.tr(AppStrings.budgetSavingsGoals),
          trailing: _LinkText(
            label: context.tr(AppStrings.budgetSeeAll),
            onTap: () {},
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _AddGoalCard(
          onTap: () => context.push(RouteNames.budgetAddGoalPath),
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        _SavingGoalsGrid(goals: tab.goals),
      ],
    );
  }
}

// ──────────────────────────── App bar ────────────────────────────

class _BudgetAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BudgetAppBar({
    required this.user,
    required this.onNotificationsTap,
    required this.onMonthlySummariesTap,
    required this.onInsightsTap,
    required this.onHistoryTap,
  });

  final dynamic user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onMonthlySummariesTap;
  final VoidCallback onInsightsTap;
  final VoidCallback onHistoryTap;

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
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.mobileMargin,
                ),
                child: Row(
                  children: [
                    HomeUserAvatar(user: user),
                    const SizedBox(width: AppSpacing.sm),
                    NotificationsBell(onTap: onNotificationsTap),
                    const Spacer(),
                    // Expense analysis insights — `GET
                    // /insights/expense-analysis`. Sits next to the
                    // budget surface because the user thinks about
                    // both "how am I spending?" and "what's the plan?"
                    // in the same context.
                    IconButton(
                      tooltip:
                          context.tr(AppStrings.insightsExpenseEntry),
                      onPressed: onInsightsTap,
                      icon: Icon(
                        Icons.insights_rounded,
                        color: scheme.onSurface,
                      ),
                    ),
                    // Historical budgets list — `GET /budgets`. Lets
                    // the user jump back to closed/archived months
                    // without re-typing the year/month manually.
                    IconButton(
                      tooltip:
                          context.tr(AppStrings.budgetsHistoryEntry),
                      onPressed: onHistoryTap,
                      icon: Icon(
                        Icons.history_rounded,
                        color: scheme.onSurface,
                      ),
                    ),
                    // Monthly summaries entry — closing/allocating the
                    // surplus is part of the saver workflow, so it
                    // belongs next to the budget tab's action surface.
                    IconButton(
                      tooltip:
                          context.tr(AppStrings.monthlySummariesEntry),
                      onPressed: onMonthlySummariesTap,
                      icon: Icon(
                        Icons.calendar_view_month_outlined,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Text(
                  context.tr(AppStrings.budgetTitle),
                  style: AppTextStyles.headlineMd(color: scheme.primary)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Section bits ────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.labelLg(color: scheme.onSurface)
              .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm(color: scheme.primary)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ──────────────────────────── Overview summary ────────────────────────────

class _OverviewSummaryCard extends StatelessWidget {
  const _OverviewSummaryCard({required this.budget});

  final BudgetModel budget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = Colors.white;
    final softFg = Colors.white.withValues(alpha: 0.78);
    final pct = (budget.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + AppSpacing.xs,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$pct%',
                  style: AppTextStyles.labelSm(color: fg)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                context.tr(AppStrings.budgetRemaining),
                style: AppTextStyles.labelMd(color: softFg),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      budget.currency,
                      style: AppTextStyles.labelLg(color: softFg),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      kHomeMoneyFormat.format(budget.remaining),
                      style: AppTextStyles.headlineXl(color: fg)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context.tr(
                AppStrings.budgetTotalAmount,
                params: {
                  'amount': kHomeMoneyFormat.format(budget.totalAmount),
                  'currency': budget.currency,
                },
              ),
              style: AppTextStyles.labelSm(color: softFg),
            ),
          ),
          // When the user has spent more than the cap the API still
          // sends `remaining: 0` (never negative). Surface the actual
          // overshoot underneath so the headline isn't misleading.
          if (budget.exceeded) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.tr(
                    AppStrings.budgetCatOver,
                    params: {
                      'amount': kHomeMoneyFormat.format(budget.overBy),
                      'currency': budget.currency,
                    },
                  ),
                  style: AppTextStyles.labelSm(color: fg)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewEmptyState extends StatelessWidget {
  const _OverviewEmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, color: scheme.primary, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(AppStrings.budgetEmptyTitle),
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLg(color: scheme.onSurface)
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.tr(AppStrings.budgetEmptyDescription),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () =>
                context.push(RouteNames.budgetAddCategoryPath),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brSm),
            ),
            child: Text(context.tr(AppStrings.budgetEmptyCta)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── Categories ────────────────────────────

class _BudgetCategoriesList extends StatelessWidget {
  const _BudgetCategoriesList({
    required this.categories,
    required this.currency,
    required this.languageCode,
  });

  final List<BudgetCategoryModel> categories;
  final String currency;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          context.tr(AppStrings.budgetCategoriesEmpty),
          style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          _BudgetCategoryItem(
            cat: categories[i],
            currency: currency,
            languageCode: languageCode,
            onTap: () => context.go(
              '/budget/category/${categories[i].id}',
            ),
          ),
          if (i < categories.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _BudgetCategoryItem extends StatelessWidget {
  const _BudgetCategoryItem({
    required this.cat,
    required this.currency,
    required this.languageCode,
    required this.onTap,
  });

  final BudgetCategoryModel cat;
  final String currency;
  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(cat.category.color) ?? scheme.primary;
    final name = cat.category.displayName(languageCode);

    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      // `shape` carries both the radius *and* the outline border, so
      // we don't pass `borderRadius` separately — Material asserts
      // they're mutually exclusive.
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Directionality(
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
                              kHomeMoneyFormat.format(cat.allocatedAmount),
                              style: AppTextStyles.labelMd(
                                color: scheme.outline,
                              ),
                            ),
                            Text(
                              ' / ',
                              style: AppTextStyles.labelMd(
                                color: scheme.outline,
                              ),
                            ),
                            Text(
                              kHomeMoneyFormat.format(cat.spentAmount),
                              style: AppTextStyles.headlineSm(
                                color: scheme.onSurface,
                              ).copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTextStyles.labelLg(color: scheme.onSurface)
                                    .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _CategoryIconBubble(
                          icon: categoryIconFor(cat.category.icon),
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  cat.exceeded
                      ? context.tr(
                          AppStrings.budgetCatOver,
                          params: {
                            'amount': kHomeMoneyFormat.format(cat.overBy),
                            'currency': currency,
                          },
                        )
                      : context.tr(
                          AppStrings.budgetCatRemaining,
                          params: {
                            'amount': kHomeMoneyFormat.format(cat.remaining),
                            'currency': currency,
                          },
                        ),
                  style: AppTextStyles.labelSm(
                    color: cat.exceeded ? scheme.error : scheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: cat.progress,
                  minHeight: 6,
                  backgroundColor:
                      scheme.outlineVariant.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    cat.exceeded ? scheme.error : scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// ──────────────────────────── Saving goals ────────────────────────────

class _AddGoalCard extends StatelessWidget {
  const _AddGoalCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brMd,
      child: _DottedBorder(
        color: scheme.primary.withValues(alpha: 0.55),
        radius: AppRadius.md,
        child: Container(
          height: 86,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, color: scheme.onPrimary, size: 18),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.tr(AppStrings.budgetAddGoal),
                style: AppTextStyles.labelMd(color: scheme.primary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingGoalsGrid extends StatelessWidget {
  const _SavingGoalsGrid({required this.goals});

  final List<SavingGoalModel> goals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (goals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          context.tr(AppStrings.budgetGoalsEmpty),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: goals.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm + AppSpacing.xs,
        crossAxisSpacing: AppSpacing.sm + AppSpacing.xs,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (_, i) => _SavingGoalCircleCard(goal: goals[i]),
    );
  }
}

class _SavingGoalCircleCard extends StatelessWidget {
  const _SavingGoalCircleCard({required this.goal});

  final SavingGoalModel goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = categoryAccentColor(goal.color) ?? scheme.primary;
    final pct = (goal.progress * 100).round();
    final icon = categoryIconFor(goal.icon);

    final paceStatus = goal.pace?.status ?? GoalPaceStatus.unknown;
    final paceBorder = goalPaceBorder(context, paceStatus);
    final paceVisuals = goalPaceVisuals(context, paceStatus);
    final showPacePill = paceVisuals.label.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(
          color: paceBorder ?? scheme.outlineVariant.withValues(alpha: 0.55),
          // Bumped width when there's a pace state so the warning
          // ring is legible at-a-glance from the budget grid.
          width: paceBorder != null ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/budget/goals/${goal.id}'),
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: goal.progress,
                            strokeWidth: 5,
                            backgroundColor:
                                scheme.outlineVariant.withValues(alpha: 0.45),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accent),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style:
                              AppTextStyles.labelMd(color: scheme.onSurface)
                                  .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Icon(icon, color: accent, size: 18),
                  const SizedBox(height: 2),
                  Text(
                    goal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMd(color: scheme.onSurface)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${kHomeMoneyFormat.format(goal.currentAmount)}'
                        ' / '
                        '${kHomeMoneyFormat.format(goal.targetAmount)}',
                        style: AppTextStyles.labelSm(color: scheme.outline),
                      ),
                    ),
                  ),
                  Text(
                    goal.currency.isNotEmpty
                        ? goal.currency
                        : AppConstants.defaultCurrency,
                    style: AppTextStyles.labelSm(color: scheme.outline),
                  ),
                ],
              ),
              if (showPacePill)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: paceVisuals.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      paceVisuals.icon,
                      size: 12,
                      color: paceVisuals.foreground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Helpers ────────────────────────────

/// Format an arbitrary `month`/`year` pair as `MMMM yyyy`.
/// Used for the empty-state fallback when no budget exists yet.
String _formatPeriod(int month, int year, String languageCode) {
  if (month < 1 || month > 12) return '';
  final d = DateTime(year > 0 ? year : DateTime.now().year, month);
  return DateFormat.yMMMM(languageCode).format(d);
}

/// Format an actual budget's period header. Prefers the
/// server-provided `period_start` so the label always matches what
/// Laravel persisted, even if [BudgetModel.month] was missing or
/// stale. Falls back to month/year when the field is empty.
String _formatBudgetPeriod(BudgetModel budget, String languageCode) {
  final start = budget.periodStartDate;
  if (start != null) {
    return DateFormat.yMMMM(languageCode).format(start);
  }
  return _formatPeriod(budget.month, budget.year, languageCode);
}

/// Tiny inline dashed border so we don't pull in another dependency
/// for a single dashed-rectangle CTA. Renders the rounded-rectangle
/// border as evenly spaced dashes.
class _DottedBorder extends StatelessWidget {
  const _DottedBorder({
    required this.child,
    required this.color,
    this.radius = 12,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.strokeWidth = 1.2,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(
        color: color,
        radius: radius,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  _DottedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        final extracted = metric.extractPath(distance, next);
        canvas.drawPath(extracted, paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace ||
      old.strokeWidth != strokeWidth;
}
