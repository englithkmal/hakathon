/// Backend endpoint paths consumed by remote data sources. Paths are
/// expressed relative to the base URL configured in
/// `AppConstants.apiBaseUrl/${AppConstants.apiVersion}`.
class ApiEndpoints {
  ApiEndpoints._();

  // ───────── Auth ─────────
  /// `POST` body: `{ phone, device_token?, platform?, locale? }`
  static const String sendOtp = '/auth/send-otp';

  /// `POST` body: `{ phone, code }` — returns either a Sanctum token + user
  /// (existing user) or `{ verified: true, is_new_user: true }` (new user).
  static const String verifyOtp = '/auth/verify-otp';

  /// `POST` body: `{ phone, code, name, email?, monthly_income?, currency, language }`
  static const String register = '/auth/register';

  /// `POST` body: `{ id_token, name?, monthly_income?, currency?, language? }`
  static const String firebaseAuth = '/auth/firebase';

  /// `GET` 🔒 — current authenticated user.
  static const String me = '/auth/me';

  /// `PUT` 🔒 body: `{ name?, email?, monthly_income?, currency?, language? }`
  static const String profile = '/auth/profile';

  /// `POST` 🔒 — invalidates the current device's token only.
  static const String logout = '/auth/logout';

  /// `POST` 🔒 — invalidates all the user's tokens.
  static const String logoutAll = '/auth/logout-all';

  // ───────── Devices (FCM) ─────────
  static const String devicesRegister = '/devices/register';
  /// `POST` body: `{ token, platform, device_name?, device_model?, app_version?, locale? }`
  /// — registers an FCM token for an unauthenticated device so it can still
  /// receive broadcast notifications. Auto-links to the user account once
  /// `/devices/register` is called with the same token after login.
  static const String devicesRegisterGuest = '/devices/register-guest';
  static const String devicesUnregister = '/devices/unregister';
  static const String devices = '/devices';
  static const String devicesTestPush = '/devices/test-push';

  // ───────── Period (active month resolver) ─────────
  /// `GET /period` 🔒 — server-side source of truth for the active month
  /// the rest of the app (dashboard, budget, insights, monthly summaries)
  /// should align to. The client calls this once on cold-start and reuses
  /// the resolved `month`/`year` everywhere.
  ///
  /// Optional query: `?month=&year=` (explicit) OR `?period_start=YYYY-MM-DD`.
  /// Without query, the server picks: latest active budget → server's
  /// current month.
  static const String period = '/period';

  // ───────── Dashboard ─────────
  static const String dashboard = '/dashboard';

  // ───────── Transactions ─────────
  static const String transactions = '/transactions';
  static String transactionById(int id) => '/transactions/$id';

  // ───────── Budgets ─────────
  static const String budgets = '/budgets';
  static const String currentBudget = '/budgets/current';
  static String budgetById(int id) => '/budgets/$id';

  // ───────── Saving Goals ─────────
  static const String savingGoals = '/saving-goals';
  static String savingGoalById(int id) => '/saving-goals/$id';

  /// `POST` 🔒 body: `{ amount, note?, transaction_date? }` — records a
  /// deposit against the goal. The server creates a backing
  /// `transaction(type=saving, saving_goal_id=id)` row so it is the
  /// source of truth for the deposit.
  static String savingGoalDeposit(int id) => '/saving-goals/$id/deposit';

  /// `GET` 🔒 query: `year?`, `month?`, `page?`, `per_page?` — paginated
  /// `transaction(type=saving)` rows for the goal.
  static String savingGoalDeposits(int id) => '/saving-goals/$id/deposits';

  /// `GET` 🔒 — month-by-month roll-up since the goal's `start_date`,
  /// with `expected` vs `deposited` and `on_track` flags. Renders the
  /// "كم وفّرت كل شهر؟" chart on the goal detail screen.
  static String savingGoalMonthlyProgress(int id) =>
      '/saving-goals/$id/monthly-progress';

  // ───────── Categories ─────────
  static const String categories = '/categories';

  // ───────── Alerts (legacy — keep for back-compat) ─────────
  static const String alerts = '/alerts';
  static String alertRead(int id) => '/alerts/$id/read';
  static const String alertsReadAll = '/alerts/read-all';
  static String alertById(int id) => '/alerts/$id';

  // ───────── Notifications (preferred unified contract) ─────────
  /// `GET` 🔒 query: `cursor?`, `limit?`, `unread_only?`, `type?`
  static const String notifications = '/notifications';
  /// `GET` 🔒 — returns `{ unread_count }`
  static const String notificationsUnreadCount = '/notifications/unread-count';
  /// `POST` 🔒 — mark a single notification as read.
  static String notificationRead(int id) => '/notifications/$id/read';
  /// `POST` 🔒 — mark all the user's notifications as read.
  static const String notificationsReadAll = '/notifications/read-all';
  /// `DELETE` 🔒 — delete a single notification.
  static String notificationById(int id) => '/notifications/$id';

  // ───────── Monthly Summaries (close-out + surplus allocation) ─────────
  /// `GET` 🔒 query: `page?`, `per_page?`, `status?` (`open` | `closed`)
  /// — paginated list of monthly summaries the server already
  /// finalised (or is currently rolling).
  static const String monthlySummaries = '/monthly-summaries';

  /// `GET` 🔒 — single monthly summary keyed by calendar period.
  /// `month` is `1..12`. The server also accepts ISO `period_start`
  /// callers, but year/month is what the UI works with.
  static String monthlySummaryByYearMonth(int year, int month) =>
      '/monthly-summaries/$year/$month';

  /// `POST` 🔒 body: `{ allocations: [{ saving_goal_id, amount, note? }] }`
  /// — moves the unallocated surplus into one or more saving goals.
  /// Returns the updated `MonthlySummaryResource`.
  static String monthlySummaryAllocate(int id) =>
      '/monthly-summaries/$id/allocate';

  // ───────── Insights ─────────
  static const String expenseAnalysis = '/insights/expense-analysis';
  static const String monthlyReport = '/insights/monthly-report';

  // ───────── Tips ─────────
  static const String tips = '/tips';
  static String tipById(int id) => '/tips/$id';

  // ───────── Mock Bank ─────────
  static const String mockBankImport = '/mock-bank/import';
  static const String mockBankClear = '/mock-bank/clear';
}
