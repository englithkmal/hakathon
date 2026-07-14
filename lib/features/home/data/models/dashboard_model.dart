// Models for `GET /dashboard` (current API contract).
//
// The backend guarantees these envelopes are never null for the home
// screen — `budget`, `last_active_budget`, `tip_of_the_day`, and the
// nested `category` objects always come back as objects with safe
// defaults (and an `exists` flag where it makes sense). Parsing here
// mirrors that contract so the UI can render without null checks.

import '../../../../core/constants/app_constants.dart';

class DashboardModel {
  const DashboardModel({
    required this.message,
    required this.currency,
    required this.period,
    required this.hasActiveBudget,
    required this.summary,
    required this.budget,
    required this.lastActiveBudget,
    required this.quickInsights,
    required this.savingsOverview,
    required this.monthTransactionsCount,
    required this.recentTransactions,
    required this.activeGoals,
    required this.unreadAlertsCount,
    required this.recentAlerts,
    required this.tipOfTheDay,
    required this.monthlySummary,
  });

  final String message;
  final String currency;
  final DashboardPeriod period;
  final bool hasActiveBudget;
  final DashboardSummary summary;
  final DashboardBudget budget;
  final DashboardLastActiveBudget lastActiveBudget;
  final List<DashboardQuickInsight> quickInsights;
  final DashboardSavingsOverview savingsOverview;
  final int monthTransactionsCount;
  final List<DashboardTransaction> recentTransactions;
  final List<DashboardGoal> activeGoals;
  final int unreadAlertsCount;
  final List<DashboardAlert> recentAlerts;
  final DashboardTip tipOfTheDay;

  /// Surfaces the latest closed monthly summary on the dashboard so
  /// the user can jump straight into allocating any leftover surplus.
  /// Always present in the response — server fills with safe
  /// defaults (`exists: false`) when there's nothing to flag.
  final DashboardMonthlySummaryBlock monthlySummary;

  /// True when there is a real, persisted budget for this period with a
  /// positive cap. Drives the "create budget" CTA vs spending visualisation.
  bool get hasBudget => budget.exists && budget.totalAmount > 0;

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      message: (json['message'] ?? '').toString(),
      currency:
          (json['currency'] ?? AppConstants.defaultCurrency).toString(),
      period: DashboardPeriod.fromJson(_asMap(json['period'])),
      hasActiveBudget: json['has_active_budget'] == true,
      summary: DashboardSummary.fromJson(_asMap(json['summary'])),
      budget: DashboardBudget.fromJson(_asMap(json['budget'])),
      lastActiveBudget: DashboardLastActiveBudget.fromJson(
        _asMap(json['last_active_budget']),
      ),
      quickInsights: _listMap(json['quick_insights'])
          .map(DashboardQuickInsight.fromJson)
          .toList(),
      savingsOverview: DashboardSavingsOverview.fromJson(
        _asMap(json['savings_overview']),
      ),
      monthTransactionsCount: _toInt(json['month_transactions_count']),
      recentTransactions: _listMap(json['recent_transactions'])
          .map(DashboardTransaction.fromJson)
          .toList(),
      activeGoals:
          _listMap(json['active_goals']).map(DashboardGoal.fromJson).toList(),
      unreadAlertsCount: _toInt(json['unread_alerts_count']),
      recentAlerts:
          _listMap(json['recent_alerts']).map(DashboardAlert.fromJson).toList(),
      tipOfTheDay: DashboardTip.fromJson(_asMap(json['tip_of_the_day'])),
      monthlySummary: DashboardMonthlySummaryBlock.fromJson(
        _asMap(json['monthly_summary']),
      ),
    );
  }
}

/// `data.monthly_summary` — drives the "last month is ready"
/// banner on the home screen. The server ships:
///
/// ```
/// {
///   "has_unread_summary": false,
///   "latest": { id, year, month, period_start, period_end,
///               allocation_status, allocated_amount,
///               unallocated_remaining, currency, closed_at },
///   "pending_unallocated_count": 0,
///   "pending_unallocated_total": "0.00"
/// }
/// ```
///
/// `latest` may be missing when the user has never closed a month.
class DashboardMonthlySummaryBlock {
  const DashboardMonthlySummaryBlock({
    required this.hasUnreadSummary,
    required this.latest,
    required this.pendingUnallocatedCount,
    required this.pendingUnallocatedTotal,
  });

  const DashboardMonthlySummaryBlock.empty()
      : hasUnreadSummary = false,
        latest = null,
        pendingUnallocatedCount = 0,
        pendingUnallocatedTotal = 0;

  /// True the first time the user opens the app after a new monthly
  /// summary was closed (server flips it back to false on read).
  final bool hasUnreadSummary;

  /// Latest closed summary — `null` when none exists yet.
  final DashboardMonthlySummaryLatest? latest;

  /// How many closed months still have non-zero unallocated remaining
  /// (typically 0 or 1).
  final int pendingUnallocatedCount;

  /// Sum of `unallocated_remaining` across all summaries in
  /// [pendingUnallocatedCount].
  final double pendingUnallocatedTotal;

  /// True when the banner should be visible on the home screen.
  /// Either there's a freshly-closed summary the user hasn't opened
  /// yet, or there's leftover surplus waiting to be allocated.
  bool get shouldShow =>
      hasUnreadSummary ||
      pendingUnallocatedCount > 0 ||
      pendingUnallocatedTotal > 0.01;

  factory DashboardMonthlySummaryBlock.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const DashboardMonthlySummaryBlock.empty();
    final latestRaw = json['latest'];
    return DashboardMonthlySummaryBlock(
      hasUnreadSummary: json['has_unread_summary'] == true ||
          json['hasUnreadSummary'] == true,
      latest: latestRaw is Map
          ? DashboardMonthlySummaryLatest.fromJson(
              latestRaw.cast<String, dynamic>(),
            )
          : null,
      pendingUnallocatedCount: _toInt(
        json['pending_unallocated_count'] ?? json['pendingUnallocatedCount'],
      ),
      pendingUnallocatedTotal: _toDouble(
        json['pending_unallocated_total'] ?? json['pendingUnallocatedTotal'],
      ),
    );
  }
}

/// `data.monthly_summary.latest` — leaner subset of
/// [MonthlySummaryModel]. We keep them as separate types because the
/// dashboard ships only the bits needed for the banner (no cash flow,
/// no top categories) and we don't want to confuse the UI by
/// hydrating phantom zeros for the missing fields.
class DashboardMonthlySummaryLatest {
  const DashboardMonthlySummaryLatest({
    required this.id,
    required this.year,
    required this.month,
    required this.periodStart,
    required this.periodEnd,
    required this.allocationStatus,
    required this.allocatedAmount,
    required this.unallocatedRemaining,
    required this.currency,
    required this.closedAt,
  });

  final int id;
  final int year;
  final int month;
  final String periodStart;
  final String periodEnd;
  final String allocationStatus;
  final double allocatedAmount;
  final double unallocatedRemaining;
  final String currency;
  final String closedAt;

  bool get hasUnallocatedRemaining => unallocatedRemaining > 0.01;

  factory DashboardMonthlySummaryLatest.fromJson(Map<String, dynamic> json) {
    return DashboardMonthlySummaryLatest(
      id: _toInt(json['id']),
      year: _toInt(json['year']),
      month: _toInt(json['month']),
      periodStart:
          (json['period_start'] ?? json['periodStart'] ?? '').toString(),
      periodEnd:
          (json['period_end'] ?? json['periodEnd'] ?? '').toString(),
      allocationStatus:
          (json['allocation_status'] ?? json['allocationStatus'] ?? '')
              .toString(),
      allocatedAmount: _toDouble(
        json['allocated_amount'] ?? json['allocatedAmount'],
      ),
      unallocatedRemaining: _toDouble(
        json['unallocated_remaining'] ?? json['unallocatedRemaining'],
      ),
      currency: (json['currency'] ?? AppConstants.defaultCurrency).toString(),
      closedAt: (json['closed_at'] ?? json['closedAt'] ?? '').toString(),
    );
  }
}

class DashboardPeriod {
  const DashboardPeriod({
    required this.month,
    required this.year,
    required this.periodStart,
    required this.periodEnd,
  });

  final int month;
  final int year;

  /// `YYYY-MM-DD` first day of the month — Laravel computes these for
  /// us so the UI doesn't have to reinvent calendar math. Empty
  /// string for older payloads.
  final String periodStart;
  final String periodEnd;

  factory DashboardPeriod.fromJson(Map<String, dynamic> json) {
    return DashboardPeriod(
      month: _toInt(json['month'], fallback: 1),
      year: _toInt(json['year'], fallback: 2026),
      periodStart: (json['period_start'] ?? json['periodStart'] ?? '')
          .toString(),
      periodEnd:
          (json['period_end'] ?? json['periodEnd'] ?? '').toString(),
    );
  }
}

/// `data.summary` — period totals (mirrors the Laravel API response):
///   - `income`         : non-salary income recorded in the period
///   - `monthly_income` : the salary figure for the period
///   - `total_income`   : monthly_income + income (the API computes it
///                        for us; we keep a fallback in case the field
///                        is missing in older payloads)
///   - `expenses`       : total expenses
///   - `savings`        : amount routed to savings
///   - `balance`        : total_income − expenses − savings
class DashboardSummary {
  const DashboardSummary({
    required this.income,
    required this.expenses,
    required this.savings,
    required this.balance,
    required this.monthlyIncome,
    required this.totalIncome,
  });

  const DashboardSummary.empty()
      : income = 0,
        expenses = 0,
        savings = 0,
        balance = 0,
        monthlyIncome = 0,
        totalIncome = 0;

  final double income;
  final double expenses;
  final double savings;
  final double balance;
  final double monthlyIncome;
  final double totalIncome;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final income = _toDouble(json['income']);
    final monthlyIncome =
        _toDouble(json['monthly_income'] ?? json['monthlyIncome']);
    final totalIncomeRaw = json['total_income'] ?? json['totalIncome'];
    return DashboardSummary(
      income: income,
      expenses: _toDouble(json['expenses']),
      savings: _toDouble(json['savings']),
      balance: _toDouble(json['balance']),
      monthlyIncome: monthlyIncome,
      totalIncome: totalIncomeRaw != null
          ? _toDouble(totalIncomeRaw)
          : monthlyIncome + income,
    );
  }
}

/// `data.budget` — always present. `exists: false` + `id: 0` when no
/// active budget exists for this period (placeholder shape).
class DashboardBudget {
  const DashboardBudget({
    required this.id,
    required this.month,
    required this.year,
    required this.totalIncome,
    required this.totalAmount,
    required this.totalSpent,
    required this.remainingApi,
    required this.progressPercentage,
    required this.currency,
    required this.status,
    required this.notes,
    required this.categories,
    required this.createdAt,
    required this.updatedAt,
    required this.exists,
  });

  const DashboardBudget.placeholder()
      : id = 0,
        month = 0,
        year = 0,
        totalIncome = 0,
        totalAmount = 0,
        totalSpent = 0,
        remainingApi = 0,
        progressPercentage = 0,
        currency = AppConstants.defaultCurrency,
        status = 'none',
        notes = '',
        categories = const [],
        createdAt = '',
        updatedAt = '',
        exists = false;

  final int id;
  final int month;
  final int year;
  final double totalIncome;
  final double totalAmount;
  final double totalSpent;
  final double remainingApi;
  final double progressPercentage;
  final String currency;
  final String status;
  final String notes;
  final List<DashboardBudgetCategory> categories;
  final String createdAt;
  final String updatedAt;
  final bool exists;

  double get spent => totalSpent;

  double get remaining =>
      remainingApi > 0 || totalAmount == 0
          ? remainingApi.clamp(0.0, double.infinity)
          : (totalAmount - totalSpent).clamp(0.0, double.infinity);

  double get progress {
    if (progressPercentage > 0) {
      return (progressPercentage / 100).clamp(0.0, 1.0);
    }
    if (totalAmount > 0) {
      return (totalSpent / totalAmount).clamp(0.0, 1.0);
    }
    return 0;
  }

  factory DashboardBudget.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const DashboardBudget.placeholder();
    final cats = _listMap(json['categories'])
        .map(DashboardBudgetCategory.fromJson)
        .toList();
    final spentDirect = _toDouble(
      json['total_spent'] ?? json['totalSpent'] ?? json['spent_amount'],
    );
    final spentFromCats = cats.fold<double>(0, (a, c) => a + c.spent);
    return DashboardBudget(
      id: _toInt(json['id']),
      month: _toInt(json['month']),
      year: _toInt(json['year']),
      totalIncome:
          _toDouble(json['total_income'] ?? json['totalIncome']),
      totalAmount: _toDouble(
        json['total_amount'] ?? json['totalAmount'] ?? json['total_budget'],
      ),
      totalSpent: spentDirect > 0 ? spentDirect : spentFromCats,
      remainingApi: _toDouble(json['remaining']),
      progressPercentage: _toDouble(
        json['progress_percentage'] ?? json['progressPercentage'],
      ),
      currency:
          (json['currency'] ?? AppConstants.defaultCurrency).toString(),
      status: (json['status'] ?? 'none').toString(),
      notes: (json['notes'] ?? '').toString(),
      categories: cats,
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      exists: json['exists'] == true,
    );
  }
}

class DashboardBudgetCategory {
  const DashboardBudgetCategory({
    required this.id,
    required this.allocatedAmount,
    required this.spent,
    required this.remaining,
    required this.usagePercentage,
    required this.alertThreshold,
    required this.category,
  });

  /// Pivot row id (`budget_categories.id`).
  final int id;
  final double allocatedAmount;
  final double spent;
  final double remaining;
  final double usagePercentage;
  final int alertThreshold;
  final DashboardCategory category;

  int get categoryId => category.id;

  factory DashboardBudgetCategory.fromJson(Map<String, dynamic> json) {
    return DashboardBudgetCategory(
      id: _toInt(json['id']),
      allocatedAmount: _toDouble(
        json['allocated_amount'] ?? json['allocatedAmount'],
      ),
      spent: _toDouble(json['spent_amount'] ?? json['spent']),
      remaining: _toDouble(json['remaining']),
      usagePercentage: _toDouble(
        json['usage_percentage'] ?? json['usagePercentage'],
      ),
      alertThreshold: _toInt(
        json['alert_threshold'] ?? json['alertThreshold'],
      ),
      category: DashboardCategory.fromJson(_asMap(json['category'])),
    );
  }
}

/// Reference wrapper for the most recent active budget — useful when the
/// current period has no budget yet but we still want to show the previous
/// month's results.
class DashboardLastActiveBudget {
  const DashboardLastActiveBudget({
    required this.exists,
    required this.budget,
    required this.period,
    required this.isCurrentPeriod,
  });

  const DashboardLastActiveBudget.empty()
      : exists = false,
        budget = const DashboardBudget.placeholder(),
        period = const DashboardPeriod(
          month: 0,
          year: 0,
          periodStart: '',
          periodEnd: '',
        ),
        isCurrentPeriod = false;

  final bool exists;
  final DashboardBudget budget;
  final DashboardPeriod period;
  final bool isCurrentPeriod;

  factory DashboardLastActiveBudget.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const DashboardLastActiveBudget.empty();
    return DashboardLastActiveBudget(
      exists: json['exists'] == true,
      budget: DashboardBudget.fromJson(_asMap(json['budget'])),
      period: DashboardPeriod.fromJson(_asMap(json['period'])),
      isCurrentPeriod: json['is_current_period'] == true,
    );
  }
}

/// One of the top-3 expense categories of the current month.
class DashboardQuickInsight {
  const DashboardQuickInsight({
    required this.category,
    required this.total,
    required this.count,
    required this.percentage,
  });

  final DashboardCategory category;
  final double total;
  final int count;
  final double percentage;

  factory DashboardQuickInsight.fromJson(Map<String, dynamic> json) {
    return DashboardQuickInsight(
      category: DashboardCategory.fromJson(_asMap(json['category'])),
      total: _toDouble(json['total']),
      count: _toInt(json['count']),
      percentage: _toDouble(json['percentage']),
    );
  }
}

/// Aggregate of all active saving goals.
class DashboardSavingsOverview {
  const DashboardSavingsOverview({
    required this.count,
    required this.totalTarget,
    required this.totalCurrent,
    required this.progressPercentage,
  });

  const DashboardSavingsOverview.empty()
      : count = 0,
        totalTarget = 0,
        totalCurrent = 0,
        progressPercentage = 0;

  final int count;
  final double totalTarget;
  final double totalCurrent;
  final double progressPercentage;

  double get progress => (progressPercentage / 100).clamp(0.0, 1.0);

  double get remaining =>
      (totalTarget - totalCurrent).clamp(0.0, double.infinity);

  factory DashboardSavingsOverview.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const DashboardSavingsOverview.empty();
    return DashboardSavingsOverview(
      count: _toInt(json['count']),
      totalTarget: _toDouble(json['total_target']),
      totalCurrent: _toDouble(json['total_current']),
      progressPercentage: _toDouble(json['progress_percentage']),
    );
  }
}

/// Embedded `category` object (also reused inside transactions & insights).
class DashboardCategory {
  const DashboardCategory({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.slug,
    required this.icon,
    required this.color,
    required this.type,
    required this.isDefault,
    required this.sortOrder,
  });

  const DashboardCategory.empty()
      : id = 0,
        name = '',
        nameAr = '',
        nameEn = '',
        slug = '',
        icon = '',
        color = '',
        type = '',
        isDefault = false,
        sortOrder = 0;

  final int id;
  final String name;
  final String nameAr;
  final String nameEn;
  final String slug;
  final String icon;
  final String color;
  final String type;
  final bool isDefault;
  final int sortOrder;

  /// Real category vs. the `id: 0` placeholder used by the API to avoid
  /// nulls.
  bool get exists => id > 0;

  /// Localised name with sensible fallbacks. Prefer the `name_*` field
  /// for the active language; fall back to `name` (already localised by
  /// `Accept-Language`) and finally to the other language code.
  String displayName(String languageCode) {
    if (languageCode == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (languageCode == 'en' && nameEn.isNotEmpty) return nameEn;
    if (name.isNotEmpty) return name;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }

  factory DashboardCategory.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const DashboardCategory.empty();
    return DashboardCategory(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: (json['name_en'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      isDefault: json['is_default'] == true,
      sortOrder: _toInt(json['sort_order']),
    );
  }
}

class DashboardTransaction {
  const DashboardTransaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.type,
    required this.description,
    required this.merchant,
    required this.source,
    required this.reference,
    required this.transactionDate,
    required this.budgetId,
    required this.category,
    required this.createdAt,
  });

  final int id;
  final double amount;
  final String currency;
  final String type;
  final String description;
  final String merchant;
  final String source;
  final String reference;
  final String transactionDate;
  final int budgetId;
  final DashboardCategory category;
  final String createdAt;

  factory DashboardTransaction.fromJson(Map<String, dynamic> json) {
    return DashboardTransaction(
      id: _toInt(json['id']),
      amount: _toDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      description: (json['description'] ?? json['title'] ?? '').toString(),
      merchant: (json['merchant'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      transactionDate:
          (json['transaction_date'] ?? json['transactionDate'] ?? '')
              .toString(),
      budgetId: _toInt(json['budget_id']),
      category: DashboardCategory.fromJson(_asMap(json['category'])),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class DashboardGoal {
  const DashboardGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingApi,
    required this.progressPercentage,
    required this.currency,
    required this.startDate,
    required this.deadline,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final double targetAmount;
  final double currentAmount;
  final double remainingApi;
  final double progressPercentage;
  final String currency;
  final String startDate;
  final String deadline;
  final String status;
  final String createdAt;

  double get progress {
    if (progressPercentage > 0) {
      return (progressPercentage / 100).clamp(0.0, 1.0);
    }
    return targetAmount > 0
        ? (currentAmount / targetAmount).clamp(0.0, 1.0)
        : 0;
  }

  double get remaining {
    if (remainingApi > 0) return remainingApi;
    return (targetAmount - currentAmount).clamp(0.0, double.infinity);
  }

  factory DashboardGoal.fromJson(Map<String, dynamic> json) {
    return DashboardGoal(
      id: _toInt(json['id']),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      targetAmount:
          _toDouble(json['target_amount'] ?? json['targetAmount']),
      currentAmount:
          _toDouble(json['current_amount'] ?? json['currentAmount']),
      remainingApi: _toDouble(json['remaining']),
      progressPercentage: _toDouble(
        json['progress_percentage'] ?? json['progressPercentage'],
      ),
      currency: (json['currency'] ?? '').toString(),
      startDate: (json['start_date'] ?? '').toString(),
      deadline: (json['deadline'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class DashboardAlert {
  const DashboardAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.payload,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String severity;
  final String title;
  final String message;
  final Map<String, dynamic> payload;
  final bool isRead;
  final String readAt;
  final String createdAt;

  /// Convenience body for tile rendering.
  String get text => message.isNotEmpty ? message : title;

  /// Heroicon-style key from the payload.
  String get payloadIcon => (payload['icon'] ?? '').toString();

  factory DashboardAlert.fromJson(Map<String, dynamic> json) {
    return DashboardAlert(
      id: _toInt(json['id']),
      type: (json['type'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      payload: _asMap(json['payload']),
      isRead: json['is_read'] == true || json['isRead'] == true,
      readAt: (json['read_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class DashboardTip {
  const DashboardTip({
    required this.id,
    required this.title,
    required this.titleAr,
    required this.titleEn,
    required this.content,
    required this.contentAr,
    required this.contentEn,
    required this.icon,
    required this.image,
    required this.audience,
    required this.category,
  });

  const DashboardTip.empty()
      : id = 0,
        title = '',
        titleAr = '',
        titleEn = '',
        content = '',
        contentAr = '',
        contentEn = '',
        icon = '',
        image = '',
        audience = '',
        category = const DashboardCategory.empty();

  final int id;
  final String title;
  final String titleAr;
  final String titleEn;
  final String content;
  final String contentAr;
  final String contentEn;
  final String icon;
  final String image;
  final String audience;
  final DashboardCategory category;

  bool get exists => id > 0 && (title.isNotEmpty || titleAr.isNotEmpty);

  String displayTitle(String languageCode) {
    if (languageCode == 'ar' && titleAr.isNotEmpty) return titleAr;
    if (languageCode == 'en' && titleEn.isNotEmpty) return titleEn;
    if (title.isNotEmpty) return title;
    return titleEn.isNotEmpty ? titleEn : titleAr;
  }

  String displayContent(String languageCode) {
    if (languageCode == 'ar' && contentAr.isNotEmpty) return contentAr;
    if (languageCode == 'en' && contentEn.isNotEmpty) return contentEn;
    if (content.isNotEmpty) return content;
    return contentEn.isNotEmpty ? contentEn : contentAr;
  }

  /// Back-compat accessor — `title` resolved by `Accept-Language`.
  String get headline => title;

  /// Back-compat accessor — `content` resolved by `Accept-Language`.
  String get subtitle => content;

  factory DashboardTip.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const DashboardTip.empty();
    return DashboardTip(
      id: _toInt(json['id']),
      title: (json['title'] ?? '').toString(),
      titleAr: (json['title_ar'] ?? '').toString(),
      titleEn: (json['title_en'] ?? '').toString(),
      content: (json['content'] ?? json['body'] ?? json['summary'] ?? '')
          .toString(),
      contentAr: (json['content_ar'] ?? '').toString(),
      contentEn: (json['content_en'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      audience: (json['audience'] ?? '').toString(),
      category: DashboardCategory.fromJson(_asMap(json['category'])),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _listMap(Object? value) {
  if (value is! List) return const [];
  return value
      .map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return e.cast<String, dynamic>();
        return const <String, dynamic>{};
      })
      .where((e) => e.isNotEmpty)
      .toList();
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
