import '../../../../core/constants/app_constants.dart';

/// Allocation status returned by the server inside `allocation.status`
/// for the detail endpoint and `allocation_status` in the list/dashboard
/// snapshots. Mirrors Laravel's enum:
///
///  * `unallocated`         — nothing of the surplus has moved yet.
///  * `partially_allocated` — some but not all of the surplus moved.
///  * `fully_allocated`     — `unallocated_remaining` is zero.
enum MonthlySummaryAllocationStatus {
  unallocated,
  partiallyAllocated,
  fullyAllocated,
  unknown;

  static MonthlySummaryAllocationStatus fromString(String? raw) {
    switch (raw) {
      case 'unallocated':
        return MonthlySummaryAllocationStatus.unallocated;
      case 'partially_allocated':
      case 'partial':
        return MonthlySummaryAllocationStatus.partiallyAllocated;
      case 'fully_allocated':
      case 'allocated':
        return MonthlySummaryAllocationStatus.fullyAllocated;
      default:
        return MonthlySummaryAllocationStatus.unknown;
    }
  }
}

/// One entry inside `top_categories[]` on the detail endpoint —
/// summarises spending per category for the closed month.
class MonthlySummaryTopCategory {
  const MonthlySummaryTopCategory({
    required this.categoryId,
    required this.nameAr,
    required this.nameEn,
    required this.total,
    required this.count,
    required this.percentage,
  });

  final int categoryId;
  final String nameAr;
  final String nameEn;
  final double total;
  final int count;
  final double percentage;

  String displayName(String languageCode) {
    if (languageCode == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (languageCode == 'en' && nameEn.isNotEmpty) return nameEn;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }

  factory MonthlySummaryTopCategory.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryTopCategory(
      categoryId: _toInt(json['category_id'] ?? json['categoryId']),
      nameAr: (json['name_ar'] ?? json['nameAr'] ?? '').toString(),
      nameEn: (json['name_en'] ?? json['nameEn'] ?? '').toString(),
      total: _toDouble(json['total'] ?? json['amount']),
      count: _toInt(json['count'] ?? json['transaction_count']),
      percentage: _toDouble(json['percentage'] ?? json['percent']),
    );
  }
}

/// Embedded budget block on the detail endpoint
/// (`budget: { id, total_amount, total_spent, adherence_pct }`).
class MonthlySummaryBudgetSnapshot {
  const MonthlySummaryBudgetSnapshot({
    required this.id,
    required this.totalAmount,
    required this.totalSpent,
    required this.adherencePct,
  });

  /// `null` when the user had no budget for that month.
  final int? id;
  final double? totalAmount;
  final double? totalSpent;

  /// Percentage of the budget consumed (`total_spent / total_amount * 100`),
  /// computed server-side. `null` when no budget.
  final double? adherencePct;

  bool get exists => id != null && (totalAmount ?? 0) > 0;

  factory MonthlySummaryBudgetSnapshot.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryBudgetSnapshot(
      id: _toIntOrNull(json['id']),
      totalAmount: _toDoubleOrNull(json['total_amount'] ?? json['totalAmount']),
      totalSpent: _toDoubleOrNull(json['total_spent'] ?? json['totalSpent']),
      adherencePct:
          _toDoubleOrNull(json['adherence_pct'] ?? json['adherencePct']),
    );
  }

  static const empty = MonthlySummaryBudgetSnapshot(
    id: null,
    totalAmount: null,
    totalSpent: null,
    adherencePct: null,
  );
}

/// Mirrors `MonthlySummaryResource` returned by:
///   * `GET /monthly-summaries`
///   * `GET /monthly-summaries/{year}/{month}`
///
/// Ships in two shapes across deploys, both handled here transparently:
///
/// 1. **New nested shape** (current spec):
///    ```
///    { id, year, month, period_start, period_end, transaction_count,
///      cash_flow: { total_income, total_expenses, total_goal_deposits,
///                   unallocated_savings },
///      allocation: { status, allocated_amount, unallocated_remaining },
///      budget: { id, total_amount, total_spent, adherence_pct },
///      top_categories: [...],
///      closed_at, closed_by, notes }
///    ```
/// 2. **Legacy flat shape** (older deploys):
///    ```
///    { id, year, month, total_income, total_expenses, total_savings,
///      surplus, allocated_surplus, unallocated_surplus, status,
///      closed_at, currency, allocations: [...] }
///    ```
///
/// The list endpoint ships a leaner subset of (1) per item — we still
/// hydrate sensible defaults so list cards and detail cards share one
/// model.
class MonthlySummaryModel {
  const MonthlySummaryModel({
    required this.id,
    required this.year,
    required this.month,
    required this.periodStart,
    required this.periodEnd,
    required this.transactionCount,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalGoalDeposits,
    required this.unallocatedSavings,
    required this.allocationStatus,
    required this.allocatedAmount,
    required this.unallocatedRemaining,
    required this.budget,
    required this.topCategories,
    required this.closedAt,
    required this.closedBy,
    required this.notes,
    required this.currency,
  });

  final int id;
  final int year;
  final int month;

  /// `YYYY-MM-DD` first day of the month.
  final String periodStart;

  /// `YYYY-MM-DD` last day of the month.
  final String periodEnd;

  /// Total transactions logged for the month — used as a "this month
  /// is empty" hint when `0`.
  final int transactionCount;

  // ─── Cash flow ───────────────────────────────────────────────
  final double totalIncome;
  final double totalExpenses;

  /// `transactions(type=saving)` for this month — what the user
  /// already moved into goals during the month itself (separate from
  /// the post-close allocation flow).
  final double totalGoalDeposits;

  /// Gross surplus before the close-out allocation
  /// (`income - expenses - goal_deposits`). Equivalent to the
  /// "السيولة الصافية للشهر" the user can pour into goals once the
  /// month is closed.
  final double unallocatedSavings;

  // ─── Allocation roll-up ──────────────────────────────────────
  final MonthlySummaryAllocationStatus allocationStatus;

  /// How much of [unallocatedSavings] was already moved into goals
  /// via the close-out allocate flow.
  final double allocatedAmount;

  /// What's left to allocate — server's authoritative figure.
  final double unallocatedRemaining;

  // ─── Embedded sub-objects ────────────────────────────────────
  final MonthlySummaryBudgetSnapshot budget;
  final List<MonthlySummaryTopCategory> topCategories;

  /// ISO timestamp the row was closed at — empty while the month is
  /// still rolling.
  final String closedAt;

  /// `cron`/`user`/etc. — informational only.
  final String closedBy;

  /// Server-side note attached to the close-out (rarely populated).
  final String notes;

  final String currency;

  // ─── Derived getters used by widgets ──────────────────────────

  /// `true` once the server has finalised the row. We treat any
  /// non-empty `closed_at` as closed since the new spec dropped the
  /// explicit `status: open|closed` field.
  bool get isClosed => closedAt.isNotEmpty;

  /// Convenience for the FAB visibility check.
  bool get hasUnallocatedSurplus => unallocatedRemaining > 0.01;

  // ─── Back-compat aliases for callers still using legacy names ─
  // The detail/list screens were originally written against the
  // flat shape. Keeping these getters lets us flip the model
  // without rewriting every consumer in the same change.
  double get totalSavings => totalGoalDeposits;
  double get surplus => unallocatedSavings;
  double get allocatedSurplus => allocatedAmount;
  double get unallocatedSurplus => unallocatedRemaining;
  String get status {
    // Map the new allocation enum back to the old open/closed binary
    // for legacy callers — `_StatusPill` on the list screen still
    // renders by `status == 'closed'`.
    return isClosed ? 'closed' : 'open';
  }

  /// Replays a server-side update onto this row — used after the
  /// allocate endpoint returns its `monthly_summary` mini-payload.
  MonthlySummaryModel applyAllocationUpdate({
    required MonthlySummaryAllocationStatus status,
    required double allocatedAmount,
    required double unallocatedRemaining,
  }) {
    return MonthlySummaryModel(
      id: id,
      year: year,
      month: month,
      periodStart: periodStart,
      periodEnd: periodEnd,
      transactionCount: transactionCount,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalGoalDeposits: totalGoalDeposits,
      unallocatedSavings: unallocatedSavings,
      allocationStatus: status,
      allocatedAmount: allocatedAmount,
      unallocatedRemaining: unallocatedRemaining,
      budget: budget,
      topCategories: topCategories,
      closedAt: closedAt,
      closedBy: closedBy,
      notes: notes,
      currency: currency,
    );
  }

  factory MonthlySummaryModel.fromJson(Map<String, dynamic> json) {
    final cashFlow = _asMap(json['cash_flow']);
    final allocation = _asMap(json['allocation']);
    final budgetMap = _asMap(json['budget']);
    final rawTopCats = json['top_categories'];

    final income = _toDouble(
      cashFlow['total_income'] ??
          json['total_income'] ??
          json['totalIncome'],
    );
    final expenses = _toDouble(
      cashFlow['total_expenses'] ??
          json['total_expenses'] ??
          json['totalExpenses'],
    );
    final goalDeposits = _toDouble(
      cashFlow['total_goal_deposits'] ??
          json['total_goal_deposits'] ??
          json['totalGoalDeposits'] ??
          json['total_savings'] ?? // legacy
          json['totalSavings'], // legacy
    );

    // Gross surplus the user is "free" to pour into goals once the
    // month closes. New spec ships it under `cash_flow`. Legacy
    // shape called the same idea `surplus` (or computed it from the
    // raw figures).
    final unallocatedSavings = _toDouble(
      cashFlow['unallocated_savings'] ??
          json['unallocated_savings'] ??
          json['surplus'] ??
          (income - expenses - goalDeposits),
    );

    // Allocation roll-up. New spec puts it under `allocation`; legacy
    // shape kept three flat fields. We accept both transparently.
    final allocStatusRaw = (allocation['status'] ??
            json['allocation_status'] ??
            json['status'])
        ?.toString();
    final allocStatus =
        MonthlySummaryAllocationStatus.fromString(allocStatusRaw);
    final allocated = _toDouble(
      allocation['allocated_amount'] ??
          json['allocated_amount'] ??
          json['allocated_surplus'] ??
          json['allocatedSurplus'],
    );
    final remainingRaw = allocation['unallocated_remaining'] ??
        json['unallocated_remaining'] ??
        json['unallocated_surplus'] ??
        json['unallocatedSurplus'];
    final remaining = remainingRaw == null
        ? (unallocatedSavings - allocated).clamp(0.0, double.infinity)
        : _toDouble(remainingRaw);

    final topCats = rawTopCats is List
        ? rawTopCats
            .whereType<Map>()
            .map((m) =>
                MonthlySummaryTopCategory.fromJson(m.cast<String, dynamic>()))
            .toList()
        : const <MonthlySummaryTopCategory>[];

    return MonthlySummaryModel(
      id: _toInt(json['id']),
      year: _toInt(json['year']),
      month: _toInt(json['month']),
      periodStart: (json['period_start'] ?? json['periodStart'] ?? '')
          .toString(),
      periodEnd:
          (json['period_end'] ?? json['periodEnd'] ?? '').toString(),
      transactionCount:
          _toInt(json['transaction_count'] ?? json['transactionCount']),
      totalIncome: income,
      totalExpenses: expenses,
      totalGoalDeposits: goalDeposits,
      unallocatedSavings: unallocatedSavings,
      allocationStatus: allocStatus,
      allocatedAmount: allocated,
      unallocatedRemaining: remaining,
      budget: budgetMap.isEmpty
          ? MonthlySummaryBudgetSnapshot.empty
          : MonthlySummaryBudgetSnapshot.fromJson(budgetMap),
      topCategories: topCats,
      closedAt: (json['closed_at'] ?? json['closedAt'] ?? '').toString(),
      closedBy: (json['closed_by'] ?? json['closedBy'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      currency:
          (json['currency'] ?? AppConstants.defaultCurrency).toString(),
    );
  }
}

/// `monthly_summary` mini-payload returned by `POST /allocate` and
/// `GET /dashboard.monthly_summary.latest`. Carries just enough to
/// refresh the parent row without re-fetching the full detail.
class MonthlySummaryUpdate {
  const MonthlySummaryUpdate({
    required this.id,
    required this.allocationStatus,
    required this.allocatedAmount,
    required this.unallocatedRemaining,
  });

  final int id;
  final MonthlySummaryAllocationStatus allocationStatus;
  final double allocatedAmount;
  final double unallocatedRemaining;

  factory MonthlySummaryUpdate.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryUpdate(
      id: _toInt(json['id']),
      allocationStatus: MonthlySummaryAllocationStatus.fromString(
        (json['allocation_status'] ?? json['allocationStatus'])?.toString(),
      ),
      allocatedAmount: _toDouble(
        json['allocated_amount'] ?? json['allocatedAmount'],
      ),
      unallocatedRemaining: _toDouble(
        json['unallocated_remaining'] ?? json['unallocatedRemaining'],
      ),
    );
  }
}

/// `saving_goal` mini-payload returned by `POST /allocate`.
class MonthlySummaryGoalUpdate {
  const MonthlySummaryGoalUpdate({
    required this.id,
    required this.currentAmount,
    required this.progressPercentage,
    required this.status,
  });

  final int id;
  final double currentAmount;
  final double progressPercentage;
  final String status;

  factory MonthlySummaryGoalUpdate.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryGoalUpdate(
      id: _toInt(json['id']),
      currentAmount: _toDouble(
        json['current_amount'] ?? json['currentAmount'],
      ),
      progressPercentage: _toDouble(
        json['progress_percentage'] ?? json['progressPercentage'],
      ),
      status: (json['status'] ?? '').toString(),
    );
  }
}

/// Triple returned by `POST /monthly-summaries/{id}/allocate`. The
/// caller uses [monthlySummary] to roll the parent row forward and
/// [savingGoal] to update the goal card cache.
class MonthlySummaryAllocateResult {
  const MonthlySummaryAllocateResult({
    required this.transactionId,
    required this.transactionAmount,
    required this.savingGoalId,
    required this.monthlySummary,
    required this.savingGoal,
  });

  final int transactionId;
  final double transactionAmount;
  final int savingGoalId;
  final MonthlySummaryUpdate monthlySummary;
  final MonthlySummaryGoalUpdate savingGoal;

  factory MonthlySummaryAllocateResult.fromJson(Map<String, dynamic> json) {
    final tx = _asMap(json['transaction']);
    return MonthlySummaryAllocateResult(
      transactionId: _toInt(tx['id']),
      transactionAmount: _toDouble(tx['amount']),
      savingGoalId: _toInt(tx['saving_goal_id'] ?? tx['savingGoalId']),
      monthlySummary: MonthlySummaryUpdate.fromJson(
        _asMap(json['monthly_summary'] ?? json['monthlySummary']),
      ),
      savingGoal: MonthlySummaryGoalUpdate.fromJson(
        _asMap(json['saving_goal'] ?? json['savingGoal']),
      ),
    );
  }
}

// ───────────────────────── Helpers ─────────────────────────

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

double _toDouble(Object? v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? _toDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _toInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

int? _toIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
