import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/app_constants.dart';
import 'budget_category_model.dart';

/// Mirrors `BudgetResource` from Laravel (`GET /budgets/current` and
/// `GET /budgets/{id}`). The `data` envelope is unwrapped before this
/// is constructed.
class BudgetModel {
  const BudgetModel({
    required this.id,
    required this.month,
    required this.year,
    required this.periodStart,
    required this.periodEnd,
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
  });

  final int id;
  final int month;
  final int year;

  /// First day of the budget month, `YYYY-MM-DD` (Laravel computes
  /// these so the client doesn't have to). Empty string when the
  /// server-side response predates the field — see [periodStartDate].
  final String periodStart;

  /// Last day of the budget month, same shape as [periodStart].
  final String periodEnd;
  final double totalIncome;
  final double totalAmount;
  final double totalSpent;

  /// Server-clamped remaining (`max(0, total_amount − total_spent)`).
  final double remainingApi;
  final double progressPercentage;
  final String currency;
  final String status;
  final String notes;
  final List<BudgetCategoryModel> categories;
  final String createdAt;
  final String updatedAt;

  /// True only when the user has actually overspent (the API never
  /// returns a negative `remaining`, so we recompute from the source).
  bool get exceeded => totalSpent > totalAmount && totalAmount > 0;

  /// "Real" remaining — clamped to 0 when over budget.
  double get remaining =>
      remainingApi > 0
          ? remainingApi
          : (totalAmount - totalSpent).clamp(0.0, double.infinity);

  /// Amount over the cap. 0 unless [exceeded].
  double get overBy => exceeded ? (totalSpent - totalAmount) : 0.0;

  /// Progress value in [0, 1]. We prefer the server-computed
  /// percentage when available, otherwise recompute from raw figures.
  double get progress {
    if (progressPercentage > 0) {
      return (progressPercentage / 100).clamp(0.0, 1.0);
    }
    if (totalAmount > 0) {
      return (totalSpent / totalAmount).clamp(0.0, 1.0);
    }
    return 0;
  }

  /// Parsed [periodStart]. Falls back to a synthesised first-of-month
  /// when the server omitted the field (older payloads or `data:null`).
  DateTime? get periodStartDate {
    final parsed = DateTime.tryParse(periodStart);
    if (parsed != null) return parsed;
    if (month >= 1 && month <= 12 && year > 1900) {
      return DateTime(year, month, 1);
    }
    return null;
  }

  /// Same fallback story as [periodStartDate], but for the last day of
  /// the budget month.
  DateTime? get periodEndDate {
    final parsed = DateTime.tryParse(periodEnd);
    if (parsed != null) return parsed;
    final start = periodStartDate;
    if (start == null) return null;
    return DateTime(start.year, start.month + 1, 0);
  }

  /// Localised "1–31 May 2026" / "١–٣١ مايو ٢٠٢٦" range label, ready
  /// to drop straight into the UI. Returns an empty string when we
  /// can't parse either bound (very old responses).
  String periodLabel(String languageCode) {
    final start = periodStartDate;
    final end = periodEndDate;
    if (start == null || end == null) return '';
    final monthName = DateFormat.MMMM(languageCode).format(start);
    return '${start.day}–${end.day} $monthName ${start.year}';
  }

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    final cats = _listMap(json['categories'])
        .map(BudgetCategoryModel.fromJson)
        .toList();
    final spentDirect = _toDouble(
      json['total_spent'] ?? json['totalSpent'] ?? json['spent_amount'],
    );
    final spentFromCats = cats.fold<double>(0, (a, c) => a + c.spentAmount);
    return BudgetModel(
      id: _toInt(json['id']),
      month: _toInt(json['month']),
      year: _toInt(json['year']),
      // New `period_*` fields ship as `YYYY-MM-DD`. Older payloads
      // (or when the server returns `data: null`) won't include them
      // — getters above synthesise sensible defaults from
      // `month`/`year` so the UI keeps working.
      periodStart: (json['period_start'] ?? json['periodStart'] ?? '')
          .toString(),
      periodEnd:
          (json['period_end'] ?? json['periodEnd'] ?? '').toString(),
      totalIncome: _toDouble(json['total_income'] ?? json['totalIncome']),
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
      status: (json['status'] ?? 'active').toString(),
      notes: (json['notes'] ?? '').toString(),
      categories: cats,
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

double _toDouble(Object? v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

List<Map<String, dynamic>> _listMap(Object? v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}
