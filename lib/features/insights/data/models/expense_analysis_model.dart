import '../../../../core/constants/app_constants.dart';
import '../../../period/data/models/selected_period.dart';

/// Per-category roll-up inside `GET /insights/expense-analysis`.
///
/// Mirrors the `categories[]` array each item carries: total spent in
/// the period, share of total spend, transaction count, and (when the
/// server can compute it) a month-over-month delta.
class ExpenseAnalysisCategory {
  const ExpenseAnalysisCategory({
    required this.categoryId,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.color,
    required this.total,
    required this.percentage,
    required this.transactionCount,
    required this.momChangePercent,
  });

  final int categoryId;

  /// Server-localised name (`Accept-Language`-respecting).
  final String name;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String color;
  final double total;

  /// `total / summary.total_spent * 100`, server-clamped to [0, 100].
  final double percentage;
  final int transactionCount;

  /// `null` when the server can't compute the comparison (e.g. no
  /// data for the previous month).
  final double? momChangePercent;

  /// Localised name with the same fallback chain `CategoryModel` uses.
  String displayName(String languageCode) {
    if (languageCode == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (languageCode == 'en' && nameEn.isNotEmpty) return nameEn;
    if (name.isNotEmpty) return name;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }

  factory ExpenseAnalysisCategory.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    final catMap = cat is Map<String, dynamic>
        ? cat
        : (cat is Map ? cat.cast<String, dynamic>() : const {});
    return ExpenseAnalysisCategory(
      categoryId: _toInt(
        json['category_id'] ?? json['categoryId'] ?? catMap['id'],
      ),
      name: (json['category_name'] ??
              json['name'] ??
              catMap['name'] ??
              '')
          .toString(),
      nameAr: (json['name_ar'] ?? catMap['name_ar'] ?? '').toString(),
      nameEn: (json['name_en'] ?? catMap['name_en'] ?? '').toString(),
      icon: (json['icon'] ?? catMap['icon'] ?? '').toString(),
      color: (json['color'] ?? catMap['color'] ?? '').toString(),
      total: _toDouble(
        json['total'] ?? json['total_spent'] ?? json['amount'],
      ),
      percentage: _toDouble(json['percentage'] ?? json['percent']),
      transactionCount: _toInt(
        json['transaction_count'] ?? json['transactionCount'] ?? json['count'],
      ),
      momChangePercent: _maybeDouble(
        json['mom_change_percent'] ??
            json['momChangePercent'] ??
            json['mom_change'],
      ),
    );
  }
}

/// Top-level summary block of `GET /insights/expense-analysis`. The
/// server may inline these fields at the root or under a `summary: {}`
/// key — we accept both shapes.
class ExpenseAnalysisSummary {
  const ExpenseAnalysisSummary({
    required this.totalSpent,
    required this.categoryCount,
    required this.transactionCount,
    required this.avgPerTransaction,
    required this.dailyAverage,
    required this.momChangePercent,
    required this.topCategoryName,
  });

  final double totalSpent;
  final int categoryCount;
  final int transactionCount;
  final double avgPerTransaction;

  /// `total_spent / number_of_days_in_period`. `0` when the server
  /// doesn't compute it; the screen falls back to a derived value.
  final double dailyAverage;

  /// Total-spend MoM% — positive = spent more this month vs the
  /// previous one. `null` when the server can't compute it.
  final double? momChangePercent;

  /// Pre-formatted name from the server's `top_category` field. Empty
  /// string when the server doesn't surface it.
  final String topCategoryName;

  factory ExpenseAnalysisSummary.fromJson(Map<String, dynamic> json) {
    final inner = json['summary'];
    final source = inner is Map<String, dynamic>
        ? inner
        : (inner is Map ? inner.cast<String, dynamic>() : json);
    return ExpenseAnalysisSummary(
      totalSpent: _toDouble(
        source['total_spent'] ??
            source['totalSpent'] ??
            source['total'],
      ),
      categoryCount: _toInt(
        source['category_count'] ?? source['categoryCount'],
      ),
      transactionCount: _toInt(
        source['transaction_count'] ?? source['transactionCount'],
      ),
      avgPerTransaction: _toDouble(
        source['avg_per_transaction'] ??
            source['avgPerTransaction'] ??
            source['average'],
      ),
      dailyAverage: _toDouble(
        source['daily_average'] ?? source['dailyAverage'],
      ),
      momChangePercent: _maybeDouble(
        source['mom_change_percent'] ??
            source['momChangePercent'] ??
            source['mom_change'],
      ),
      topCategoryName: (source['top_category_name'] ??
              source['topCategoryName'] ??
              _readMapName(source['top_category']) ??
              '')
          .toString(),
    );
  }

  static String? _readMapName(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return (raw['name'] ?? raw['name_en'] ?? raw['name_ar'])?.toString();
    }
    if (raw is Map) {
      final cast = raw.cast<String, dynamic>();
      return (cast['name'] ?? cast['name_en'] ?? cast['name_ar'])
          ?.toString();
    }
    return null;
  }
}

/// Top-level payload for `GET /insights/expense-analysis`. Carries the
/// summary block, the per-category breakdown, the period the server
/// resolved the analysis against, and the active currency.
class ExpenseAnalysisModel {
  const ExpenseAnalysisModel({
    required this.summary,
    required this.categories,
    required this.serverPeriod,
    required this.currency,
  });

  final ExpenseAnalysisSummary summary;
  final List<ExpenseAnalysisCategory> categories;

  /// Period the analysis was computed against (mirrors `meta.period`
  /// on the dashboard / budget endpoints).
  final SelectedPeriod serverPeriod;

  final String currency;

  bool get isEmpty => summary.totalSpent <= 0 && categories.isEmpty;

  factory ExpenseAnalysisModel.fromJson(Map<String, dynamic> json) {
    // Some Laravel responses wrap the body in `data`, others ship it
    // flat — the data source is responsible for unwrapping. We still
    // be defensive about either shape just in case.
    final payload = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawCats = payload['categories'] ??
        payload['by_category'] ??
        payload['breakdown'];
    final categoryList = rawCats is List
        ? rawCats
            .whereType<Map>()
            .map((m) => ExpenseAnalysisCategory.fromJson(
                  m.cast<String, dynamic>(),
                ))
            .toList()
        : <ExpenseAnalysisCategory>[];

    SelectedPeriod period;
    final meta = json['meta'] ?? payload['meta'];
    Map<String, dynamic>? periodMap;
    if (meta is Map<String, dynamic>) {
      final p = meta['period'];
      if (p is Map<String, dynamic>) periodMap = p;
    }
    if (periodMap == null && payload['period'] is Map<String, dynamic>) {
      periodMap = payload['period'] as Map<String, dynamic>;
    }
    period = periodMap != null
        ? SelectedPeriod.fromJson(periodMap)
        : SelectedPeriod.localFallback();

    final currency = (payload['currency'] ??
            (meta is Map<String, dynamic> ? meta['currency'] : null) ??
            AppConstants.defaultCurrency)
        .toString();

    return ExpenseAnalysisModel(
      summary: ExpenseAnalysisSummary.fromJson(payload),
      categories: categoryList,
      serverPeriod: period,
      currency: currency,
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

/// Like [_toDouble] but returns `null` when the server omits the field
/// (so the UI can render "no comparison data" instead of "0%").
double? _maybeDouble(Object? v) {
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
