/// Authenticated user profile returned by the Waffer backend.
///
/// The Laravel `UserResource` returns `name` (not `full_name`) plus the
/// finance-specific extras: `monthly_income`, `currency`, `language`. We
/// stay forgiving for camelCase too so the same model survives schema
/// drift.
class UserModel {
  const UserModel({
    required this.id,
    required this.phoneE164,
    this.name,
    this.email,
    this.avatarUrl,
    this.monthlyIncome,
    this.currency,
    this.language,
  });

  final String id;
  final String phoneE164;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final num? monthlyIncome;
  final String? currency;
  final String? language;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      phoneE164:
          (json['phone'] ?? json['phone_e164'] ?? json['phoneE164'] ?? '')
              .toString(),
      name: json['name'] as String? ??
          json['full_name'] as String? ??
          json['fullName'] as String?,
      email: json['email'] as String?,
      avatarUrl:
          json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      monthlyIncome: _toNum(json['monthly_income'] ?? json['monthlyIncome']),
      currency: json['currency'] as String?,
      language: (json['language'] ?? json['locale']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phoneE164,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (monthlyIncome != null) 'monthly_income': monthlyIncome,
        if (currency != null) 'currency': currency,
        if (language != null) 'language': language,
      };

  UserModel copyWith({
    String? id,
    String? phoneE164,
    String? name,
    String? email,
    String? avatarUrl,
    num? monthlyIncome,
    String? currency,
    String? language,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneE164: phoneE164 ?? this.phoneE164,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      currency: currency ?? this.currency,
      language: language ?? this.language,
    );
  }

  static num? _toNum(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}
