/// Single category from `GET /categories`.
///
/// Mirrors the embedded `category` shape used by `/dashboard` and
/// `/transactions`, with `name_ar` / `name_en` so the client can pick the
/// right label without relying on `Accept-Language`.
class CategoryModel {
  const CategoryModel({
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

  const CategoryModel.empty()
      : id = 0,
        name = '',
        nameAr = '',
        nameEn = '',
        slug = '',
        icon = '',
        color = '',
        type = 'expense',
        isDefault = false,
        sortOrder = 0;

  final int id;
  final String name;
  final String nameAr;
  final String nameEn;
  final String slug;
  final String icon;
  final String color;

  /// `expense` | `income`.
  final String type;
  final bool isDefault;
  final int sortOrder;

  bool get exists => id > 0;
  bool get isExpense => type != 'income';

  /// Localised name. Prefer the `name_*` field for the requested language;
  /// fall back to the locale-neutral `name` (already localised by
  /// `Accept-Language`) and finally the other language code.
  String displayName(String languageCode) {
    if (languageCode == 'ar' && nameAr.isNotEmpty) return nameAr;
    if (languageCode == 'en' && nameEn.isNotEmpty) return nameEn;
    if (name.isNotEmpty) return name;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const CategoryModel.empty();
    return CategoryModel(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: (json['name_en'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      type: (json['type'] ?? 'expense').toString(),
      isDefault: json['is_default'] == true,
      sortOrder: _toInt(json['sort_order']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_ar': nameAr,
        'name_en': nameEn,
        'slug': slug,
        'icon': icon,
        'color': color,
        'type': type,
        'is_default': isDefault,
        'sort_order': sortOrder,
      };
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}
