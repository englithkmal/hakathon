/// Embedded category reference returned inside `budget_categories` rows.
/// Mirrors the shape of `CategoryResource` (id, name, slug, icon, …).
class BudgetCategoryRefModel {
  const BudgetCategoryRefModel({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.nameEn,
    required this.slug,
    required this.icon,
    required this.color,
    required this.type,
  });

  final int id;

  /// Server-localized name (depends on `Accept-Language`).
  final String name;
  final String nameAr;
  final String nameEn;
  final String slug;
  final String icon;
  final String color;

  /// `expense` | `income`.
  final String type;

  /// Pick the best display name for the active locale, with sensible
  /// fallbacks when one of the localized fields is missing.
  String displayName(String languageCode) {
    if (languageCode == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (languageCode == 'en' && nameEn.isNotEmpty) return nameEn;
    if (name.isNotEmpty) return name;
    return nameAr.isNotEmpty ? nameAr : nameEn;
  }

  factory BudgetCategoryRefModel.fromJson(Map<String, dynamic> json) {
    return BudgetCategoryRefModel(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? json['nameAr'] ?? '').toString(),
      nameEn: (json['name_en'] ?? json['nameEn'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      type: (json['type'] ?? 'expense').toString(),
    );
  }
}

/// One row from `budget.categories[]` — i.e. a *budget allocation* for
/// a category, not the global category itself.
class BudgetCategoryModel {
  const BudgetCategoryModel({
    required this.id,
    required this.category,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.remainingApi,
    required this.usagePercentage,
    required this.alertThreshold,
  });

  /// Pivot row id (`budget_categories.id`), useful for PATCH/DELETE.
  final int id;
  final BudgetCategoryRefModel category;
  final double allocatedAmount;
  final double spentAmount;

  /// Server-clamped remaining (`max(0, allocated − spent)`).
  final double remainingApi;
  final double usagePercentage;
  final int alertThreshold;

  /// True when the category went over its allocation.
  bool get exceeded =>
      allocatedAmount > 0 && spentAmount > allocatedAmount;

  /// Negative-aware "remaining": stays 0 once exceeded.
  double get remaining =>
      remainingApi > 0
          ? remainingApi
          : (allocatedAmount - spentAmount).clamp(0.0, double.infinity);

  /// How much over the cap the user spent. 0 when not exceeded.
  double get overBy =>
      exceeded ? (spentAmount - allocatedAmount) : 0.0;

  /// Progress value for a `LinearProgressIndicator`. Always in [0, 1]
  /// even when the user is over budget — caller decides the colour.
  double get progress {
    if (allocatedAmount <= 0) return 0;
    return (spentAmount / allocatedAmount).clamp(0.0, 1.0);
  }

  factory BudgetCategoryModel.fromJson(Map<String, dynamic> json) {
    return BudgetCategoryModel(
      id: _toInt(json['id']),
      category: BudgetCategoryRefModel.fromJson(_asMap(json['category'])),
      allocatedAmount: _toDouble(
        json['allocated_amount'] ?? json['allocatedAmount'],
      ),
      spentAmount:
          _toDouble(json['spent_amount'] ?? json['spent'] ?? json['spentAmount']),
      remainingApi: _toDouble(json['remaining']),
      usagePercentage: _toDouble(
        json['usage_percentage'] ?? json['usagePercentage'],
      ),
      alertThreshold: _toInt(
        json['alert_threshold'] ?? json['alertThreshold'],
      ),
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

Map<String, dynamic> _asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  return const {};
}
