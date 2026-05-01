import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../monthly_summaries/presentation/widgets/monthly_summary_banner.dart';
import '../../../period/presentation/widgets/latest_budget_banner.dart';
import '../../data/data_sources/home_remote_data_source.dart';
import '../../data/models/dashboard_model.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/budget_card.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/quick_insights_card.dart';
import '../widgets/recent_transactions_section.dart';
import '../widgets/savings_card.dart';
import '../widgets/tip_of_the_day_card.dart';
import '../widgets/total_balance_card.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final asyncDash = ref.watch(dashboardProvider);
    final lang = ref.watch(localeProvider).languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: HomeFigmaAppBar(
        user: user,
        // `push` keeps Home on the stack so the system back gesture
        // returns here instead of exiting the app.
        onNotificationsTap: () => context.push(RouteNames.notificationsPath),
        onQuickSaveTap: () => context.go(RouteNames.budgetPath),
      ),
      body: asyncDash.when(
        data: (shell) => RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
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
                child: _HomeLoadedBody(shell: shell, languageCode: lang),
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
                  style: AppTextStyles.bodyMd(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(dashboardProvider),
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

/// Headline figure shown inside the activity card (with the chart).
///
/// We never repeat the total balance here — that already lives in the
/// dedicated `HomeTotalBalanceCard` above. Instead:
///   - With an active budget: show the remaining budget so the user
///     can see how much room is left vs. their plan.
///   - Without a budget: show this month's salary (`monthly_income`)
///     as a useful counterpart to the `expenses` figure rendered on
///     the opposite side. Any extra non-salary income is surfaced as
///     a small chip underneath, so it isn't lost.
double _homeHeadlineBalance(DashboardModel d) {
  if (d.hasBudget) return d.budget.remaining;
  return d.summary.monthlyIncome;
}

class _HomeLoadedBody extends StatelessWidget {
  const _HomeLoadedBody({required this.shell, required this.languageCode});

  final HomeShellData shell;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final d = shell.dashboard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Spec: surface a banner when the server fell back to the
        // user's latest active budget month (period.source =
        // latest_budget). No-ops for any other source.
        LatestBudgetBanner(period: shell.serverPeriod),
        // Surface the "last month is ready" / "X surplus waiting to
        // be allocated" banner above the headline balance so the
        // user sees the close-out CTA before scrolling. The widget
        // returns SizedBox.shrink() when the block has nothing to
        // flag.
        MonthlySummaryBanner(block: d.monthlySummary),
        HomeTotalBalanceCard(
          balance: d.summary.balance,
          totalIncome: d.summary.totalIncome,
          currency: d.currency,
        ),
        const SizedBox(height: AppSpacing.md),
        HomeBalanceCard(
          dashboard: d,
          balance: _homeHeadlineBalance(d),
          monthlyExpenses: d.summary.expenses,
          momPercent: shell.balanceChangePercent,
        ),
        const SizedBox(height: AppSpacing.md),
        HomeSavingsCard(
          goals: d.activeGoals,
          savingsOverview: d.savingsOverview,
          currency: d.currency,
        ),
        const SizedBox(height: AppSpacing.md),
        HomeBudgetCard(dashboard: d),
        if (d.quickInsights.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          HomeQuickInsightsCard(
            insights: d.quickInsights,
            languageCode: languageCode,
            currency: d.currency,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        HomeRecentTransactionsSection(
          transactions: d.recentTransactions,
          languageCode: languageCode,
          fallbackCurrency: d.currency,
        ),
        const SizedBox(height: AppSpacing.lg),
        HomeTipOfTheDayCard(
          tip: d.tipOfTheDay,
          languageCode: languageCode,
          onCtaTap: () => context.go(RouteNames.transactionsPath),
        ),
      ],
    );
  }
}
