import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../home/presentation/utils/home_money.dart';
import '../../../period/presentation/providers/selected_period_provider.dart';
import '../../data/models/budget_model.dart';
import '../providers/budgets_list_provider.dart';

/// Top-level history screen for `GET /budgets`.
///
/// Lives outside the bottom-nav shell so its AppBar can host a back
/// arrow and the screen takes the full viewport. Tapping a row pins
/// [selectedPeriodProvider] to that budget's month and pops back into
/// the budget tab so the user lands on the expected period.
class BudgetsListScreen extends ConsumerStatefulWidget {
  const BudgetsListScreen({super.key});

  @override
  ConsumerState<BudgetsListScreen> createState() => _BudgetsListScreenState();
}

class _BudgetsListScreenState extends ConsumerState<BudgetsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 200px lookahead — kicks in before the user actually hits the
    // bottom so the spinner sits at the tail of the list rather than
    // appearing as a jump after a stall.
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(budgetsListProvider.notifier).loadMore();
    }
  }

  Future<void> _onRowTap(BuildContext context, BudgetModel budget) async {
    // Pin the period before popping so the budget tab rebuilds with
    // the correct month on the way back. We don't await the network
    // — `setExplicit` updates state synchronously enough that the
    // tab's listener picks up the new value before its next build.
    await ref
        .read(selectedPeriodProvider.notifier)
        .setExplicit(month: budget.month, year: budget.year);
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.budgetPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = ref.watch(localeProvider).languageCode;
    final asyncList = ref.watch(budgetsListProvider);

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
          context.tr(AppStrings.budgetsHistoryTitle),
          style: AppTextStyles.headlineSm(color: scheme.onSurface)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: asyncList.when(
        data: (data) {
          if (data.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(budgetsListProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  _EmptyState(),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(budgetsListProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.mobileMargin,
                AppSpacing.md,
                AppSpacing.mobileMargin,
                MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
              ),
              itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
              itemBuilder: (_, i) {
                if (i >= data.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final budget = data.items[i];
                return _BudgetHistoryCard(
                  budget: budget,
                  languageCode: lang,
                  onTap: () => _onRowTap(context, budget),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.read(budgetsListProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _BudgetHistoryCard extends StatelessWidget {
  const _BudgetHistoryCard({
    required this.budget,
    required this.languageCode,
    required this.onTap,
  });

  final BudgetModel budget;
  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthLabel = DateFormat.yMMMM(languageCode)
        .format(DateTime(budget.year, budget.month, 1));
    final progress = budget.progress;
    // Bar colour: red when overspent, amber when ≥ 80% of the cap,
    // primary otherwise. Mirrors the same semantics used by the
    // budget overview card so the user sees consistent signals.
    final Color barColor;
    if (budget.exceeded) {
      barColor = scheme.error;
    } else if (progress >= 0.8) {
      barColor = AppColors.amber500;
    } else {
      barColor = scheme.primary;
    }
    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      monthLabel,
                      style: AppTextStyles.headlineSm(color: scheme.onSurface)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _StatusPill(status: budget.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      scheme.outlineVariant.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              _MetricRow(
                label: context.tr(AppStrings.budgetsHistoryAllocated),
                value: kHomeMoneyFormat.format(budget.totalAmount),
                currency: budget.currency,
                color: scheme.onSurface,
              ),
              const SizedBox(height: 4),
              _MetricRow(
                label: context.tr(AppStrings.budgetsHistorySpent),
                value: kHomeMoneyFormat.format(budget.totalSpent),
                currency: budget.currency,
                color: scheme.error,
              ),
              const SizedBox(height: 4),
              _MetricRow(
                label: context.tr(
                  budget.exceeded
                      ? AppStrings.budgetsHistoryOverBy
                      : AppStrings.budgetsHistoryRemaining,
                ),
                value: kHomeMoneyFormat.format(
                  budget.exceeded ? budget.overBy : budget.remaining,
                ),
                currency: budget.currency,
                color: budget.exceeded ? scheme.error : AppColors.green700,
                emphasised: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'closed':
        bg = AppColors.teal100;
        fg = AppColors.teal700;
        label = context.tr(AppStrings.budgetsHistoryStatusClosed);
        break;
      case 'archived':
        bg = scheme.surfaceContainerHigh;
        fg = scheme.onSurfaceVariant;
        label = context.tr(AppStrings.budgetsHistoryStatusArchived);
        break;
      case 'active':
      default:
        bg = AppColors.green100;
        fg = AppColors.green700;
        label = context.tr(AppStrings.budgetsHistoryStatusActive);
        break;
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final String currency;
  final Color color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySm(
              color: emphasised ? scheme.onSurface : scheme.onSurfaceVariant,
            ).copyWith(
              fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            '$value $currency',
            style: AppTextStyles.bodyMd(color: color)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mobileMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.tr(AppStrings.budgetsHistoryEmptyTitle),
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSm(color: scheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(AppStrings.budgetsHistoryEmptySubtitle),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mobileMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(AppStrings.budgetsHistoryLoadFailed),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.tr(AppStrings.commonRetry)),
            ),
          ],
        ),
      ),
    );
  }
}
