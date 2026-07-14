/// Centralised route names + paths for the app.
class RouteNames {
  RouteNames._();

  // Splash (shown while we hydrate auth state from storage on cold start)
  static const String splash = 'splash';
  static const String splashPath = '/';

  // Onboarding
  static const String onboarding = 'onboarding';
  static const String onboardingPath = '/onboarding';

  // Auth
  static const String login = 'login';
  static const String register = 'register';
  static const String loginPath = '/login';
  static const String registerPath = '/login/register';

  // Shell tabs
  static const String home = 'home';
  static const String transactions = 'transactions';
  static const String budget = 'budget';
  static const String profile = 'profile';

  static const String homePath = '/home';
  static const String transactionsPath = '/transactions';
  static const String budgetPath = '/budget';
  static const String profilePath = '/profile';

  // Sub-routes
  static const String addTransaction = 'addTransaction';
  static const String addTransactionPath = '/transactions/add';

  static const String budgetCategoryDetail = 'budgetCategoryDetail';
  /// Path param `:id` is `budget_categories.id` (the pivot row), *not*
  /// the global category id. The detail screen looks the row up inside
  /// the cached `budgetTabProvider` data.
  static const String budgetCategoryDetailPath = '/budget/category/:id';

  static const String budgetAddCategory = 'budgetAddCategory';
  static const String budgetAddCategoryPath = '/budget/categories/add';

  static const String budgetAddGoal = 'budgetAddGoal';
  static const String budgetAddGoalPath = '/budget/goals/add';

  /// Detail screen for a single saving goal: pace, monthly progress,
  /// recent deposits + the deposit bottom-sheet. Lives outside the
  /// shell so it has its own AppBar / FAB and full-bleed layout.
  static const String savingGoalDetail = 'savingGoalDetail';
  static const String savingGoalDetailPath = '/budget/goals/:id';

  static const String settings = 'settings';
  static const String settingsPath = 'settings';

  static const String notifications = 'notifications';
  static const String notificationsPath = '/notifications';

  /// Top-level "Monthly summaries" list — `GET /monthly-summaries`.
  static const String monthlySummaries = 'monthlySummaries';
  static const String monthlySummariesPath = '/monthly-summaries';

  /// Per-month detail — `GET /monthly-summaries/{year}/{month}` plus
  /// the "allocate surplus" sheet.
  static const String monthlySummaryDetail = 'monthlySummaryDetail';
  static const String monthlySummaryDetailPath =
      '/monthly-summaries/:year/:month';

  /// `GET /insights/expense-analysis` — per-category spending breakdown
  /// for the active period with MoM deltas.
  static const String insightsExpense = 'insightsExpense';
  static const String insightsExpensePath = '/insights/expense-analysis';

  /// `GET /budgets` — paginated history of every budget the user owns
  /// (active + closed + archived). Tapping a row anchors the rest of
  /// the app to that budget's month via [selectedPeriodProvider].
  static const String budgetsHistory = 'budgetsHistory';
  static const String budgetsHistoryPath = '/budgets/history';
}
