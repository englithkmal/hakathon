import 'user_model.dart';

/// What we persist locally after a successful authentication.
///
/// Waffer issues Laravel Sanctum tokens (`"1|abc..."`) which don't expire
/// by default — `expiresAt` and `refreshToken` stay nullable for forward
/// compatibility but are normally not present.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final UserModel? user;

  /// Builds a session from a successful auth response payload (the inner
  /// `data` object — caller is responsible for unwrapping the envelope).
  ///
  /// Accepts variations:
  /// - token: `token` (Waffer) / `access_token` / `accessToken`
  /// - refresh: `refresh_token` / `refreshToken`
  /// - expiry: `expires_in` (seconds) / `expires_at` (ISO 8601)
  /// - user: `user` (object) — optional
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final access = (json['token'] ??
            json['access_token'] ??
            json['accessToken'] ??
            '')
        .toString();

    final refresh =
        (json['refresh_token'] ?? json['refreshToken']) as String?;

    DateTime? expiresAt;
    final expiresIn = json['expires_in'] ?? json['expiresIn'];
    if (expiresIn is int) {
      expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    } else if (expiresIn is String) {
      final secs = int.tryParse(expiresIn);
      if (secs != null) {
        expiresAt = DateTime.now().add(Duration(seconds: secs));
      }
    }
    final expiresAtRaw = json['expires_at'] ?? json['expiresAt'];
    if (expiresAtRaw is String) {
      expiresAt = DateTime.tryParse(expiresAtRaw) ?? expiresAt;
    }

    UserModel? user;
    final userRaw = json['user'];
    if (userRaw is Map<String, dynamic>) {
      user = UserModel.fromJson(userRaw);
    }

    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt,
      user: user,
    );
  }

  Map<String, dynamic> toJson() => {
        'token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        if (user != null) 'user': user!.toJson(),
      };

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    UserModel? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      user: user ?? this.user,
    );
  }
}
