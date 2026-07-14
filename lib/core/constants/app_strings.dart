/// Translation keys used across the app.
///
/// The actual strings live in `assets/translations/{ar,en}.json` and are
/// resolved through [AppLocalizations].
class AppStrings {
  AppStrings._();

  // App
  static const String appTitle = 'app.title';

  // Navigation
  static const String navHome = 'nav.home';
  static const String navTransactions = 'nav.transactions';
  static const String navBudget = 'nav.budget';
  static const String navProfile = 'nav.profile';

  // Common
  static const String commonCurrency = 'common.currency';
  static const String commonNotifications = 'common.notifications';
  static const String commonViewAll = 'common.viewAll';
  static const String commonAdd = 'common.add';
  static const String commonRemaining = 'common.remaining';
  static const String commonOf = 'common.of';
  static const String commonRetry = 'common.retry';
  static const String commonEmpty = 'common.empty';
  static const String commonClose = 'common.close';
  static const String commonError = 'common.error';
  static const String commonEdit = 'common.edit';
  static const String commonDelete = 'common.delete';
  static const String commonCancel = 'common.cancel';
  static const String commonGenericError = 'common.genericError';

  // Home
  static const String homeOverview = 'home.overview';
  static const String homeGreetingMorning = 'home.greeting.morning';
  static const String homeGreetingAfternoon = 'home.greeting.afternoon';
  static const String homeGreetingEvening = 'home.greeting.evening';
  static const String homeGreetingMorningWithName = 'home.greeting.morningWithName';
  static const String homeGreetingAfternoonWithName = 'home.greeting.afternoonWithName';
  static const String homeGreetingEveningWithName = 'home.greeting.eveningWithName';
  static const String homeQuickAddSaving = 'home.quickAddSaving';
  static const String homeMonthlyExpenses = 'home.monthlyExpenses';
  static const String homeMonthlyIncome = 'home.monthlyIncome';
  static const String homeMonthlySalary = 'home.monthlySalary';
  static const String homeExtraIncome = 'home.extraIncome';
  static const String homeTotalIncome = 'home.totalIncome';
  static const String homeWeekShort = 'home.weekShort';
  static const String homeWeekN = 'home.weekN';
  static const String homeSavingsLabel = 'home.savingsLabel';
  static const String homeSavingsRemaining = 'home.savingsRemaining';
  static const String homeBudgetLabel = 'home.budgetLabel';
  static const String homeBudgetActiveStatus = 'home.budgetActiveStatus';
  static const String homeBudgetUsageHint = 'home.budgetUsageHint';
  static const String homeRecentTransactions = 'home.recentTransactions';
  static const String homeNoActiveGoal = 'home.noActiveGoal';
  static const String homeTipOfTheDay = 'home.tipOfTheDay';
  static const String homeTipExploreCta = 'home.tipExploreCta';
  static const String homeTotalBalance = 'home.totalBalance';
  static const String homeBudgetRemaining = 'home.budgetRemaining';
  static const String homeBalanceHide = 'home.balance.hide';
  static const String homeBalanceShow = 'home.balance.show';
  static const String homeQuickInsightsTitle = 'home.quickInsights.title';
  static const String homeQuickInsightsSubtitle = 'home.quickInsights.subtitle';
  static const String homeQuickInsightsTxCount = 'home.quickInsights.txCount';
  static const String homeQuickInsightsEmpty = 'home.quickInsights.empty';
  static const String homeTrendThisMonth = 'home.trendThisMonth';
  static const String homeSpendingVsBudget = 'home.spendingVsBudget';
  static const String homeSpent = 'home.spent';
  static const String homeQuickInsights = 'home.quickInsights';
  static const String homeSavingsGoals = 'home.savingsGoals';
  static const String homeRemainingAmount = 'home.remainingAmount';
  static const String homeGoalProgressSubtitle = 'home.goalProgressSubtitle';
  static const String homeLoadFailed = 'home.loadFailed';
  static const String homeNotificationsSoon = 'home.notificationsSoon';
  static const String homeInsightFallbackSubtitle = 'home.insightFallbackSubtitle';
  static const String homeNoBudgetHint = 'home.noBudgetHint';

  // Period banner (rendered when the server returned `source = latest_budget`
  // — i.e. the user is viewing the latest budget month rather than the
  // server's current calendar month).
  static const String periodLatestBudgetTitle = 'period.latestBudget.title';
  static const String periodLatestBudgetSubtitle =
      'period.latestBudget.subtitle';
  static const String periodLatestBudgetBackToToday =
      'period.latestBudget.backToToday';

  // Transactions
  static const String transactionsTitle = 'transactions.title';
  static const String transactionsAdd = 'transactions.add';
  static const String transactionsAddSection = 'transactions.addSection';
  static const String transactionsAmount = 'transactions.amount';
  static const String transactionsAmountWithCurrency =
      'transactions.amountWithCurrency';
  static const String transactionsAmountHint = 'transactions.amountHint';
  static const String transactionsCategory = 'transactions.category';
  static const String transactionsCategoryRequired =
      'transactions.categoryRequired';
  static const String transactionsAmountInvalid =
      'transactions.amountInvalid';
  static const String transactionsHistory = 'transactions.history';
  static const String transactionsToday = 'transactions.today';
  static const String transactionsYesterday = 'transactions.yesterday';
  static const String transactionsEmpty = 'transactions.empty';
  static const String transactionsCreated = 'transactions.created';
  static const String transactionsCategoriesEmpty =
      'transactions.categoriesEmpty';
  static const String transactionsLoadFailed = 'transactions.loadFailed';
  static const String transactionsTypeExpense = 'transactions.type.expense';
  static const String transactionsTypeIncome = 'transactions.type.income';
  static const String transactionsAddExpenseTitle = 'transactions.addExpenseTitle';
  static const String transactionsAddIncomeTitle = 'transactions.addIncomeTitle';
  static const String transactionsAmountEnterHint = 'transactions.amountEnterHint';
  static const String transactionsNoteLabel = 'transactions.noteLabel';
  static const String transactionsNoteHint = 'transactions.noteHint';
  static const String transactionsDateLabel = 'transactions.dateLabel';
  static const String transactionsDateToday = 'transactions.dateToday';
  static const String transactionsSaveButton = 'transactions.saveButton';
  static const String transactionsCategoryOther = 'transactions.categoryOther';

  // Transactions — edit / delete
  static const String transactionsEditTitle = 'transactions.edit.title';
  static const String transactionsEditAmountLabel =
      'transactions.edit.amountLabel';
  static const String transactionsEditCategoryLabel =
      'transactions.edit.categoryLabel';
  static const String transactionsEditCategoriesEmpty =
      'transactions.edit.categoriesEmpty';
  static const String transactionsEditNoteLabel =
      'transactions.edit.noteLabel';
  static const String transactionsEditNoteHint =
      'transactions.edit.noteHint';
  static const String transactionsEditDateLabel =
      'transactions.edit.dateLabel';
  static const String transactionsEditSubmit = 'transactions.edit.submit';
  static const String transactionsEditSuccess = 'transactions.edit.success';
  static const String transactionsDeleteTitle = 'transactions.delete.title';
  static const String transactionsDeleteBody = 'transactions.delete.body';
  static const String transactionsDeleteSuccess =
      'transactions.delete.success';

  // Notifications
  static const String notificationsTitle = 'notifications.title';
  static const String notificationsMarkAllRead = 'notifications.markAllRead';
  static const String notificationsAllReadSnack = 'notifications.allReadSnack';
  static const String notificationsLoadFailed = 'notifications.loadFailed';
  static const String notificationsEmptyTitle = 'notifications.emptyTitle';
  static const String notificationsEmptySubtitle =
      'notifications.emptySubtitle';
  static const String notificationsNoOlder = 'notifications.noOlder';
  static const String notificationsGroupToday = 'notifications.group.today';
  static const String notificationsGroupYesterday =
      'notifications.group.yesterday';
  static const String notificationsGroupThisWeek =
      'notifications.group.thisWeek';
  static const String notificationsGroupOlder = 'notifications.group.older';
  static const String notificationsGoalProgressLabel =
      'notifications.goal.progressLabel';
  static const String notificationsBudgetReviewCta =
      'notifications.budget.reviewCta';
  static const String notificationsTimeMinutesAgo =
      'notifications.time.minutesAgo';
  static const String notificationsTimeHoursAgo =
      'notifications.time.hoursAgo';
  static const String notificationsTimeDaysAgo = 'notifications.time.daysAgo';
  static const String notificationsTimeJustNow = 'notifications.time.justNow';

  // Categories
  static const String categoryFood = 'category.food';
  static const String categoryTransport = 'category.transport';
  static const String categoryShopping = 'category.shopping';
  static const String categorySalary = 'category.salary';
  static const String categoryHousing = 'category.housing';
  static const String categoryEntertainment = 'category.entertainment';
  static const String categoryOther = 'category.other';

  // Budget
  static const String budgetTitle = 'budget.title';
  static const String budgetMonthly = 'budget.monthly';
  static const String budgetRemaining = 'budget.remaining';
  static const String budgetTotal = 'budget.total';
  static const String budgetSavingsGoals = 'budget.savingsGoals';
  static const String budgetAddGoal = 'budget.addGoal';
  static const String budgetOverviewTitle = 'budget.overviewTitle';
  static const String budgetCategoriesTitle = 'budget.categoriesTitle';
  static const String budgetAddCategory = 'budget.addCategory';
  static const String budgetSeeAll = 'budget.seeAll';
  static const String budgetTotalAmount = 'budget.totalAmount';
  static const String budgetCatRemaining = 'budget.catRemaining';
  static const String budgetCatOver = 'budget.catOver';
  static const String budgetEmptyTitle = 'budget.empty.title';
  static const String budgetEmptyDescription = 'budget.empty.description';
  static const String budgetEmptyCta = 'budget.empty.cta';
  static const String budgetGoalsEmpty = 'budget.goals.empty';
  static const String budgetCategoriesEmpty = 'budget.categories.empty';
  static const String budgetDetailTitle = 'budget.detail.title';
  static const String budgetDetailEdit = 'budget.detail.edit';
  static const String budgetDetailRemainingLabel = 'budget.detail.remainingLabel';
  static const String budgetDetailSpentLabel = 'budget.detail.spentLabel';
  static const String budgetDetailTotalLabel = 'budget.detail.totalLabel';
  static const String budgetDetailDailyAvg = 'budget.detail.dailyAvg';
  static const String budgetDetailDaysLeft = 'budget.detail.daysLeft';
  static const String budgetDetailDaysLeftValue = 'budget.detail.daysLeftValue';
  static const String budgetDetailRecentOps = 'budget.detail.recentOps';
  static const String budgetDetailToday = 'budget.detail.today';
  static const String budgetDetailYesterday = 'budget.detail.yesterday';
  static const String budgetDetailEmpty = 'budget.detail.empty';
  static const String budgetAddTitle = 'budget.add.title';
  static const String budgetAddHeroTitle = 'budget.add.heroTitle';
  static const String budgetAddNameLabel = 'budget.add.nameLabel';
  static const String budgetAddNameHint = 'budget.add.nameHint';
  static const String budgetAddNameSelected = 'budget.add.nameSelected';
  static const String budgetAddLimitLabel = 'budget.add.limitLabel';
  static const String budgetAddLimitHint = 'budget.add.limitHint';
  static const String budgetAddPickIcon = 'budget.add.pickIcon';
  static const String budgetAddSubmit = 'budget.add.submit';
  static const String budgetAddTipTitle = 'budget.add.tipTitle';
  static const String budgetAddTipBody = 'budget.add.tipBody';
  static const String budgetAddSuccess = 'budget.add.success';
  static const String budgetAddErrorPickCategory = 'budget.add.errorPickCategory';
  static const String budgetAddErrorAmount = 'budget.add.errorAmount';
  static const String budgetAddNoCategories = 'budget.add.noCategories';
  static const String budgetAddAlreadyAdded = 'budget.add.alreadyAdded';
  static const String budgetAddGoalTitle = 'budget.addGoal.title';
  static const String budgetAddGoalHeroTitle = 'budget.addGoal.heroTitle';
  static const String budgetAddGoalHeroSubtitle = 'budget.addGoal.heroSubtitle';
  static const String budgetAddGoalNameLabel = 'budget.addGoal.nameLabel';
  static const String budgetAddGoalNameHint = 'budget.addGoal.nameHint';
  static const String budgetAddGoalAmountLabel = 'budget.addGoal.amountLabel';
  static const String budgetAddGoalDeadlineLabel = 'budget.addGoal.deadlineLabel';
  static const String budgetAddGoalDeadlineHint = 'budget.addGoal.deadlineHint';
  static const String budgetAddGoalPickIcon = 'budget.addGoal.pickIcon';
  static const String budgetAddGoalSubmit = 'budget.addGoal.submit';
  static const String budgetAddGoalForecastTitle = 'budget.addGoal.forecastTitle';
  static const String budgetAddGoalForecastNote = 'budget.addGoal.forecastNote';
  static const String budgetAddGoalForecastHint = 'budget.addGoal.forecastHint';
  static const String budgetAddGoalSuccess = 'budget.addGoal.success';
  static const String budgetAddGoalErrorPickGoal = 'budget.addGoal.errorPickGoal';
  static const String budgetAddGoalErrorAmount = 'budget.addGoal.errorAmount';
  static const String budgetAddGoalErrorDeadline = 'budget.addGoal.errorDeadline';
  static const String budgetAddGoalIconEducation = 'budget.addGoal.icon.education';
  static const String budgetAddGoalIconTools = 'budget.addGoal.icon.tools';
  static const String budgetAddGoalIconHome = 'budget.addGoal.icon.home';
  static const String budgetAddGoalIconTravel = 'budget.addGoal.icon.travel';
  static const String budgetAddGoalIconCar = 'budget.addGoal.icon.car';
  static const String budgetAddGoalIconGift = 'budget.addGoal.icon.gift';
  static const String budgetAddGoalIconWedding = 'budget.addGoal.icon.wedding';
  static const String budgetAddGoalIconOther = 'budget.addGoal.icon.other';

  // Goal — status enum (active / paused / cancelled / achieved)
  static const String goalStatusActive = 'goal.status.active';
  static const String goalStatusPaused = 'goal.status.paused';
  static const String goalStatusCancelled = 'goal.status.cancelled';
  static const String goalStatusAchieved = 'goal.status.achieved';

  // Goal — edit / delete
  static const String goalEditTitle = 'goal.edit.title';
  static const String goalEditStatusLabel = 'goal.edit.statusLabel';
  static const String goalEditSubmit = 'goal.edit.submit';
  static const String goalEditSuccess = 'goal.edit.success';
  static const String goalDeleteTitle = 'goal.delete.title';
  static const String goalDeleteBody = 'goal.delete.body';
  static const String goalDeleteSuccess = 'goal.delete.success';

  // Budgets history (`GET /budgets`)
  static const String budgetsHistoryTitle = 'budgets.history.title';
  static const String budgetsHistoryEntry = 'budgets.history.entry';
  static const String budgetsHistoryEmptyTitle =
      'budgets.history.emptyTitle';
  static const String budgetsHistoryEmptySubtitle =
      'budgets.history.emptySubtitle';
  static const String budgetsHistoryLoadFailed =
      'budgets.history.loadFailed';
  static const String budgetsHistoryStatusActive =
      'budgets.history.status.active';
  static const String budgetsHistoryStatusClosed =
      'budgets.history.status.closed';
  static const String budgetsHistoryStatusArchived =
      'budgets.history.status.archived';
  static const String budgetsHistoryAllocated =
      'budgets.history.allocated';
  static const String budgetsHistorySpent = 'budgets.history.spent';
  static const String budgetsHistoryRemaining =
      'budgets.history.remaining';
  static const String budgetsHistoryOverBy = 'budgets.history.overBy';
  static const String budgetsHistoryViewBudget =
      'budgets.history.viewBudget';

  // Insights — expense analysis (`GET /insights/expense-analysis`)
  static const String insightsExpenseTitle = 'insights.expense.title';
  static const String insightsExpenseEntry = 'insights.expense.entry';
  static const String insightsExpenseLoadFailed =
      'insights.expense.loadFailed';
  static const String insightsExpenseEmpty = 'insights.expense.empty';
  static const String insightsExpenseTotalSpent =
      'insights.expense.totalSpent';
  static const String insightsExpenseTransactions =
      'insights.expense.transactions';
  static const String insightsExpenseAvgPerTransaction =
      'insights.expense.avgPerTransaction';
  static const String insightsExpenseDailyAverage =
      'insights.expense.dailyAverage';
  static const String insightsExpenseTopCategory =
      'insights.expense.topCategory';
  static const String insightsExpenseMomUp = 'insights.expense.momUp';
  static const String insightsExpenseMomDown = 'insights.expense.momDown';
  static const String insightsExpenseMomFlat = 'insights.expense.momFlat';
  static const String insightsExpenseCategoriesTitle =
      'insights.expense.categoriesTitle';
  static const String insightsExpenseCategoryShare =
      'insights.expense.categoryShare';
  static const String insightsExpenseCategoryTxnCount =
      'insights.expense.categoryTxnCount';

  // Monthly summaries
  static const String monthlySummariesTitle = 'monthly.summaries.title';
  static const String monthlySummariesEntry = 'monthly.summaries.entry';
  static const String monthlySummariesEmptyTitle =
      'monthly.summaries.emptyTitle';
  static const String monthlySummariesEmptySubtitle =
      'monthly.summaries.emptySubtitle';
  static const String monthlySummariesLoadFailed =
      'monthly.summaries.loadFailed';
  static const String monthlySummariesStatusOpen =
      'monthly.summaries.status.open';
  static const String monthlySummariesStatusClosed =
      'monthly.summaries.status.closed';
  static const String monthlySummariesIncome =
      'monthly.summaries.income';
  static const String monthlySummariesExpenses =
      'monthly.summaries.expenses';
  static const String monthlySummariesSavings =
      'monthly.summaries.savings';
  static const String monthlySummariesSurplus =
      'monthly.summaries.surplus';
  static const String monthlySummariesAllocatedSurplus =
      'monthly.summaries.allocatedSurplus';
  static const String monthlySummariesUnallocatedSurplus =
      'monthly.summaries.unallocatedSurplus';
  static const String monthlySummariesAllocateCta =
      'monthly.summaries.allocateCta';
  static const String monthlySummariesAllocationsTitle =
      'monthly.summaries.allocationsTitle';
  static const String monthlySummariesAllocationsEmpty =
      'monthly.summaries.allocationsEmpty';

  // Detail screen — allocation pill, top categories, budget adherence
  static const String monthlyAllocationFully =
      'monthly.summaries.allocation.fully';
  static const String monthlyAllocationPartial =
      'monthly.summaries.allocation.partial';
  static const String monthlyAllocationNone =
      'monthly.summaries.allocation.none';
  static const String monthlyTopCategoriesTitle =
      'monthly.summaries.topCategories.title';
  static const String monthlyBudgetAdherence =
      'monthly.summaries.budget.adherence';

  // Dashboard banner — surfaced when has_unread_summary or
  // pending_unallocated_count > 0 (see monthly_summary block in
  // GET /dashboard).
  static const String dashboardSummaryBannerNew =
      'dashboard.monthlySummary.banner.new';
  static const String dashboardSummaryBannerPending =
      'dashboard.monthlySummary.banner.pending';
  static const String dashboardSummaryBannerCta =
      'dashboard.monthlySummary.banner.cta';
  static const String dashboardSummaryBannerAllocateCta =
      'dashboard.monthlySummary.banner.allocateCta';

  // Allocate surplus sheet
  static const String allocateSheetTitle = 'allocate.sheet.title';
  static const String allocateSheetIntro = 'allocate.sheet.intro';
  static const String allocateSheetGoalLabel = 'allocate.sheet.goalLabel';
  static const String allocateSheetGoalPlaceholder =
      'allocate.sheet.goalPlaceholder';
  static const String allocateSheetAmountLabel =
      'allocate.sheet.amountLabel';
  static const String allocateSheetRemaining = 'allocate.sheet.remaining';
  static const String allocateSheetOverflow = 'allocate.sheet.overflow';
  static const String allocateSheetAddRow = 'allocate.sheet.addRow';
  static const String allocateSheetRemoveRow = 'allocate.sheet.removeRow';
  static const String allocateSheetSubmit = 'allocate.sheet.submit';
  static const String allocateSheetSuccess = 'allocate.sheet.success';
  static const String allocateSheetNoGoals = 'allocate.sheet.noGoals';

  // Goal — pace pill
  static const String goalPaceAhead = 'goal.pace.ahead';
  static const String goalPaceOnTrack = 'goal.pace.onTrack';
  static const String goalPaceOffTrack = 'goal.pace.offTrack';
  static const String goalPaceInactive = 'goal.pace.inactive';
  static const String goalPaceUnscheduled = 'goal.pace.unscheduled';

  // Goal — detail screen
  static const String goalDetailTitle = 'goal.detail.title';
  static const String goalDetailMonthlyTarget = 'goal.detail.monthlyTarget';
  static const String goalDetailExpectedToday = 'goal.detail.expectedToday';
  static const String goalDetailDeltaAhead = 'goal.detail.deltaAhead';
  static const String goalDetailDeltaBehind = 'goal.detail.deltaBehind';
  static const String goalDetailDeltaOnTrack = 'goal.detail.deltaOnTrack';
  static const String goalDetailMonthlyProgress =
      'goal.detail.monthlyProgress';
  static const String goalDetailMonthlyProgressEmpty =
      'goal.detail.monthlyProgressEmpty';
  static const String goalDetailRecentDeposits = 'goal.detail.recentDeposits';
  static const String goalDetailRecentDepositsEmpty =
      'goal.detail.recentDepositsEmpty';
  static const String goalDetailLoadFailed = 'goal.detail.loadFailed';

  // Goal — deposit form
  static const String goalDepositCta = 'goal.deposit.cta';
  static const String goalDepositSheetTitle = 'goal.deposit.sheetTitle';
  static const String goalDepositAmountLabel = 'goal.deposit.amountLabel';
  static const String goalDepositAmountHint = 'goal.deposit.amountHint';
  static const String goalDepositAmountInvalid = 'goal.deposit.amountInvalid';
  static const String goalDepositNoteLabel = 'goal.deposit.noteLabel';
  static const String goalDepositNoteHint = 'goal.deposit.noteHint';
  static const String goalDepositDateLabel = 'goal.deposit.dateLabel';
  static const String goalDepositDateToday = 'goal.deposit.dateToday';
  static const String goalDepositSubmit = 'goal.deposit.submit';
  static const String goalDepositSuccess = 'goal.deposit.success';

  // Profile
  static const String profileTitle = 'profile.title';
  static const String profileAccountSettings = 'profile.accountSettings';
  static const String profileAppSettings = 'profile.appSettings';
  static const String profilePreferences = 'profile.preferences';
  static const String profileBankAccounts = 'profile.bankAccounts';
  static const String profileSecurity = 'profile.security';
  static const String profileNotifications = 'profile.notifications';
  static const String profileDarkMode = 'profile.darkMode';
  static const String profileLanguage = 'profile.language';
  static const String profileCurrency = 'profile.currency';
  static const String profileCurrencyPickTitle = 'profile.currency.pickTitle';
  static const String profileCurrencyHint = 'profile.currency.hint';
  static const String profileCurrencyUpdated = 'profile.currency.updated';
  static const String profileCurrencyError = 'profile.currency.error';

  // Profile — currency change confirmation dialog
  static const String profileCurrencyConfirmTitle =
      'profile.currency.confirm.title';
  static const String profileCurrencyConfirmIntro =
      'profile.currency.confirm.intro';
  static const String profileCurrencyConfirmFromTo =
      'profile.currency.confirm.fromTo';
  static const String profileCurrencyConfirmReason1 =
      'profile.currency.confirm.reason1';
  static const String profileCurrencyConfirmReason2 =
      'profile.currency.confirm.reason2';
  static const String profileCurrencyConfirmReason3 =
      'profile.currency.confirm.reason3';
  static const String profileCurrencyConfirmRecommended =
      'profile.currency.confirm.recommended';
  static const String profileCurrencyConfirmCancel =
      'profile.currency.confirm.cancel';
  static const String profileCurrencyConfirmProceed =
      'profile.currency.confirm.proceed';
  static const String profileLogout = 'profile.logout';
  static const String profileLogoutConfirm = 'profile.logoutConfirm';

  // Profile — hero badges
  static const String profileBadgePlatinum = 'profile.badge.platinum';
  static const String profileBadgeVerified = 'profile.badge.verified';

  // Profile — banks section
  static const String profileBanksTitle = 'profile.banks.title';
  static const String profileBanksAdd = 'profile.banks.add';
  static const String profileBanksDisconnected = 'profile.banks.disconnected';
  static const String profileBanksSampleAlrajhi = 'profile.banks.sampleAlrajhi';
  static const String profileBanksSampleAlahli = 'profile.banks.sampleAlahli';

  // Profile — preferences section
  static const String profilePrefsTitle = 'profile.prefs.title';
  static const String profilePrefsExpenseAlerts = 'profile.prefs.expenseAlerts';

  // Profile — version footer
  static const String profileAppVersion = 'profile.appVersion';

  // Currencies — long localised names
  static const String currencyNameSar = 'currency.name.SAR';
  static const String currencyNameJod = 'currency.name.JOD';
  static const String currencyNameUsd = 'currency.name.USD';
  static const String currencyNameAed = 'currency.name.AED';
  static const String currencyNameEur = 'currency.name.EUR';

  // Onboarding
  static const String onboardingSkip = 'onboarding.skip';
  static const String onboardingNext = 'onboarding.next';
  static const String onboardingGetStarted = 'onboarding.getStarted';
  static const String onboarding1Title = 'onboarding.page1.title';
  static const String onboarding1Body = 'onboarding.page1.body';
  static const String onboarding2Title = 'onboarding.page2.title';
  static const String onboarding2Body = 'onboarding.page2.body';
  static const String onboarding3Title = 'onboarding.page3.title';
  static const String onboarding3Body = 'onboarding.page3.body';

  // Auth — Login (phone)
  static const String authSignInAppBarTitle = 'auth.signin.appBarTitle';
  static const String authWelcomeHeading = 'auth.welcome.heading';
  static const String authWelcomeTagline = 'auth.welcome.tagline';
  static const String authWelcomeTitle = 'auth.welcome.title';
  static const String authWelcomeSubtitle = 'auth.welcome.subtitle';
  static const String authPhoneLabel = 'auth.phone.label';
  static const String authPhoneHint = 'auth.phone.hint';
  static const String authPhoneInvalid = 'auth.phone.invalid';
  static const String authContinue = 'auth.continue';
  static const String authTermsNote = 'auth.termsNote';
  static const String authTermsNotePrefix = 'auth.termsNote.prefix';
  static const String authTermsNoteTerms = 'auth.termsNote.terms';
  static const String authTermsNoteAnd = 'auth.termsNote.and';
  static const String authTermsNotePrivacy = 'auth.termsNote.privacy';
  static const String authTermsNoteSuffix = 'auth.termsNote.suffix';

  // Auth — Password
  static const String authPasswordLabel = 'auth.password.label';
  static const String authPasswordHint = 'auth.password.hint';
  static const String authPasswordTooShort = 'auth.password.tooShort';
  static const String authLoginSubmit = 'auth.login.submit';
  static const String authLoginInvalid = 'auth.login.invalid';
  static const String authNoAccountYet = 'auth.login.noAccountYet';
  static const String authCreateAccountLink = 'auth.login.createAccountLink';
  static const String authHaveAccountAlready = 'auth.register.haveAccountAlready';
  static const String authGoToLoginLink = 'auth.register.goToLoginLink';
  static const String authConfirmPasswordLabel = 'auth.register.confirmPassword';
  static const String authPasswordsDontMatch = 'auth.register.passwordsDontMatch';

  // Auth — Register (new user)
  static const String authRegisterTitle = 'auth.register.title';
  static const String authRegisterSubtitle = 'auth.register.subtitle';
  static const String authRegisterName = 'auth.register.name';
  static const String authRegisterNameHint = 'auth.register.nameHint';
  static const String authRegisterNameRequired = 'auth.register.nameRequired';
  static const String authRegisterEmail = 'auth.register.email';
  static const String authRegisterEmailHint = 'auth.register.emailHint';
  static const String authRegisterEmailInvalid = 'auth.register.emailInvalid';
  static const String authRegisterIncome = 'auth.register.income';
  static const String authRegisterIncomeHint = 'auth.register.incomeHint';
  static const String authRegisterCurrency = 'auth.register.currency';
  static const String authRegisterLanguage = 'auth.register.language';
  static const String authRegisterSubmit = 'auth.register.submit';
  static const String authRegisterPhoneLabel = 'auth.register.phoneLabel';
  static const String authLanguageArabic = 'auth.language.arabic';
  static const String authLanguageEnglish = 'auth.language.english';
}
