/// Metadata returned by `POST /auth/send-otp`. Drives the OTP screen's
/// expiry timer + resend cooldown + the optional "delivered via push" hint.
class OtpRequestInfo {
  const OtpRequestInfo({
    required this.isNewUser,
    required this.expiresIn,
    required this.cooldownSeconds,
    this.delivery,
    this.hint,
  });

  /// `true` → after `verify-otp` we'll need to call `register` to finish
  /// onboarding. `false` → existing user, verify-otp returns the token.
  final bool isNewUser;

  /// Seconds before the OTP code itself expires (server-side validity).
  final int expiresIn;

  /// Seconds the user must wait before requesting a new OTP.
  final int cooldownSeconds;

  /// `push` | `sms` | etc. — the channel through which the OTP was sent.
  final String? delivery;

  /// Localised hint text the backend wants the user to see.
  final String? hint;

  factory OtpRequestInfo.fromJson(Map<String, dynamic> json) {
    return OtpRequestInfo(
      isNewUser: json['is_new_user'] as bool? ?? false,
      expiresIn: _toInt(json['expires_in']) ?? 120,
      cooldownSeconds: _toInt(json['cooldown_seconds']) ?? 60,
      delivery: json['delivery'] as String?,
      hint: json['hint'] as String?,
    );
  }

  static int? _toInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
