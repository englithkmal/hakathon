import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/budget/presentation/screens/budget_add_category_screen.dart';
import '../../features/budget/presentation/screens/budget_add_goal_screen.dart';
import '../../features/budget/presentation/screens/budget_category_detail_screen.dart';
import '../../features/budget/presentation/screens/budget_overview_screen.dart';
import '../../features/budget/presentation/screens/budgets_list_screen.dart';
import '../../features/budget/presentation/screens/saving_goal_detail_screen.dart';
import '../../features/insights/presentation/screens/expense_analysis_screen.dart';
import '../../features/monthly_summaries/presentation/screens/monthly_summaries_list_screen.dart';
import '../../features/monthly_summaries/presentation/screens/monthly_summary_detail_screen.dart';
import '../../features/home/presentation/screens/home_dashboard_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/transactions/presentation/screens/transactions_history_screen.dart';
import '../widgets/app_bottom_nav.dart';
import 'route_names.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RouteNames.splashPath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final onboarding = ref.read(onboardingProvider);
      final loc = state.matchedLocation;

      final onSplash = loc == RouteNames.splashPath;
      final onOnboarding = loc == RouteNames.onboardingPath;
      final onLogin = loc == RouteNames.loginPath;
      final onRegister = loc == RouteNames.registerPath;
      final onAuthRoute = onLogin || onRegister;

      // While we're still hydrating the session from storage, hold on the
      // splash. This is what removes the "/login → /home" flicker on cold
      // start when the user already has a saved session.
      if (auth is AuthInitializing) {
        return onSplash ? null : RouteNames.splashPath;
      }

      // Authenticated users skip past onboarding/auth altogether.
      if (auth is AuthAuthenticated) {
        return (onSplash || onAuthRoute || onOnboarding)
            ? RouteNames.homePath
            : null;
      }

      // Anyone who hasn't seen onboarding is forced through it first.
      if (onboarding == OnboardingStatus.pending) {
        return onOnboarding ? null : RouteNames.onboardingPath;
      }

      // Unauthenticated and onboarding done → /login or /login/register.
      return onAuthRoute ? null : RouteNames.loginPath;
    },
    routes: [
      GoRoute(
        path: RouteNames.splashPath,
        name: RouteNames.splash,
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: RouteNames.onboardingPath,
        name: RouteNames.onboarding,
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
      ),
      ),
      GoRoute(
        path: RouteNames.registerPath,
        name: RouteNames.register,
        pageBuilder: (context, state) =>
            _fadePage(state, const RegisterScreen()),
      ),
      // Notifications lives outside the bottom-nav shell so it covers
      // the whole screen and the back button drops the user back into
      // whichever tab they came from.
      GoRoute(
        path: RouteNames.notificationsPath,
        name: RouteNames.notifications,
        pageBuilder: (context, state) =>
            _fadePage(state, const NotificationsScreen()),
      ),
      // Full-screen "Add transaction" sheet. Lives outside the shell so
      // the bottom-nav and any tab UI is replaced by the keypad-driven
      // sheet, and back drops the user into the previous tab.
      GoRoute(
        path: RouteNames.addTransactionPath,
        name: RouteNames.addTransaction,
        pageBuilder: (context, state) =>
            _slideUpPage(state, const AddTransactionScreen()),
      ),
      // Budget category detail. Outside the shell because the screen
      // has its own AppBar with a back-arrow and full-bleed layout.
      GoRoute(
        path: RouteNames.budgetCategoryDetailPath,
        name: RouteNames.budgetCategoryDetail,
        pageBuilder: (context, state) {
          final raw = state.pathParameters['id'] ?? '0';
          final id = int.tryParse(raw) ?? 0;
          return _fadePage(
            state,
            BudgetCategoryDetailScreen(budgetCategoryId: id),
          );
        },
      ),
      // Budget — add category screen. Same rationale as the detail
      // route: full-screen, own AppBar, lives outside the shell so it
      // doesn't get the bottom nav layered on top.
      GoRoute(
        path: RouteNames.budgetAddCategoryPath,
        name: RouteNames.budgetAddCategory,
        pageBuilder: (context, state) =>
            _fadePage(state, const BudgetAddCategoryScreen()),
      ),
      // Budget — add saving-goal screen. Outside the shell for the
      // same reason as the add-category route above.
      GoRoute(
        path: RouteNames.budgetAddGoalPath,
        name: RouteNames.budgetAddGoal,
        pageBuilder: (context, state) =>
            _fadePage(state, const BudgetAddGoalScreen()),
      ),
      // Saving goal detail. Path param `:id` is `saving_goals.id`. The
      // screen pulls the goal record from the cached `budgetTabProvider`
      // and only hits the network for the per-goal endpoints
      // (`/monthly-progress`, `/deposits`, `/deposit`).
      GoRoute(
        path: RouteNames.savingGoalDetailPath,
        name: RouteNames.savingGoalDetail,
        pageBuilder: (context, state) {
          final raw = state.pathParameters['id'] ?? '0';
          final id = int.tryParse(raw) ?? 0;
          return _fadePage(state, SavingGoalDetailScreen(goalId: id));
        },
      ),
      // Monthly summaries list — `GET /monthly-summaries`. Lives outside
      // the bottom-nav shell so the AppBar can host its own back button
      // and the screen takes the full viewport.
      GoRoute(
        path: RouteNames.monthlySummariesPath,
        name: RouteNames.monthlySummaries,
        pageBuilder: (context, state) =>
            _fadePage(state, const MonthlySummariesListScreen()),
      ),
      // Per-month detail + "allocate surplus" sheet. Path params
      // are the calendar year/month (NOT the database id) — the
      // detail endpoint is keyed by period to keep deep links
      // human-readable.
      GoRoute(
        path: RouteNames.monthlySummaryDetailPath,
        name: RouteNames.monthlySummaryDetail,
        pageBuilder: (context, state) {
          final year = int.tryParse(state.pathParameters['year'] ?? '') ??
              DateTime.now().year;
          final month = int.tryParse(state.pathParameters['month'] ?? '') ??
              DateTime.now().month;
          return _fadePage(
            state,
            MonthlySummaryDetailScreen(year: year, month: month),
          );
        },
      ),
      // Expense analysis insights — `GET /insights/expense-analysis`.
      // Lives outside the shell so the AppBar back arrow drops the
      // user back into whichever tab launched the screen.
      GoRoute(
        path: RouteNames.insightsExpensePath,
        name: RouteNames.insightsExpense,
        pageBuilder: (context, state) =>
            _fadePage(state, const ExpenseAnalysisScreen()),
      ),
      // All-budgets history list — `GET /budgets`. Outside the shell
      // so tapping a row can pop back into whichever tab launched it
      // after pinning the period via [selectedPeriodProvider].
      GoRoute(
        path: RouteNames.budgetsHistoryPath,
        name: RouteNames.budgetsHistory,
        pageBuilder: (context, state) =>
            _fadePage(state, const BudgetsListScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.homePath,
                name: RouteNames.home,
                pageBuilder: (context, state) => _fadePage(
                  state,
                  const HomeDashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.transactionsPath,
                name: RouteNames.transactions,
                pageBuilder: (context, state) => _fadePage(
                  state,
                  const TransactionsHistoryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.budgetPath,
                name: RouteNames.budget,
                pageBuilder: (context, state) => _fadePage(
                  state,
                  const BudgetOverviewScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profilePath,
                name: RouteNames.profile,
                pageBuilder: (context, state) => _fadePage(
                  state,
                  const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridge that turns the auth + onboarding providers into a [Listenable]
/// consumable by [GoRouter.refreshListenable].
class _GoRouterRefresh extends ChangeNotifier {
  _GoRouterRefresh(Ref ref) {
    _authSub = ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
    _onboardingSub = ref.listen<OnboardingStatus>(
      onboardingProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription<AuthState> _authSub;
  late final ProviderSubscription<OnboardingStatus> _onboardingSub;

  @override
  void dispose() {
    _authSub.close();
    _onboardingSub.close();
    super.dispose();
  }
}

CustomTransitionPage<T> _fadePage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

CustomTransitionPage<T> _slideUpPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Tab index for the Transactions branch — must mirror the order of
  /// `branches` in [GoRouter] above.
  static const int _transactionsBranchIndex = 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showFab =
        navigationShell.currentIndex == _transactionsBranchIndex;
    return Scaffold(
      body: navigationShell,
      // Floating "quick add transaction" button. Scoped to the
      // Transactions tab so it doesn't compete with the Home / Budget /
      // Profile primary actions.
      floatingActionButton: showFab
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FloatingActionButton(
                heroTag: 'add-transaction-fab',
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 6,
                shape: const CircleBorder(),
                // `push` (not `go`) so the Transactions tab remains on
                // the navigation stack — system back gesture then collapses
                // the sheet instead of exiting the app.
                onPressed: () => GoRouter.of(context).push(
                  RouteNames.addTransactionPath,
                ),
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: _goBranch,
      ),
    );
  }
}
