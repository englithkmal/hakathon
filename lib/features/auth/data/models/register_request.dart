/// Body for `POST /auth/register`.
///
/// Called when `verify-otp` returns `is_new_user: true`. The backend
/// re-validates the OTP code, so we forward the same `phone` + `code`
/// pair and let the user fill in profile info.
///
/// Mirrors `VerifyOtpBody` for the device fields: sending `device_token`
/// + `platform` + `locale` (+ optional device meta) lets the backend link
/// the FCM token to the new account on the same request, so notifications
/// start flowing the moment registration completes.
class RegisterBody {
  const RegisterBody({
    required this.phoneE164,
    required this.code,
    required this.name,
    required this.currency,
    required this.language,
    this.email,
    this.monthlyIncome,
    this.deviceToken,
    this.platform,
    this.locale,
    this.deviceName,
    this.deviceModel,
    this.appVersion,
  });

  final String phoneE164;
  final String code;
  final String name;
  final String currency; // SAR | JOD | USD | AED | EUR
  final String language; // ar | en
  final String? email;
  final num? monthlyIncome;

  final String? deviceToken;
  final String? platform; // android | ios | web
  final String? locale; // ar | en
  final String? deviceName;
  final String? deviceModel;
  final String? appVersion;

  Map<String, dynamic> toJson() => {
        'phone': phoneE164,
        'code': code,
        'name': name,
        'currency': currency,
        'language': language,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (monthlyIncome != null) 'monthly_income': monthlyIncome,
        if (deviceToken != null && deviceToken!.isNotEmpty)
          'device_token': deviceToken,
        if (platform != null && platform!.isNotEmpty) 'platform': platform,
        if (locale != null && locale!.isNotEmpty) 'locale': locale,
        if (deviceName != null && deviceName!.isNotEmpty)
          'device_name': deviceName,
        if (deviceModel != null && deviceModel!.isNotEmpty)
          'device_model': deviceModel,
        if (appVersion != null && appVersion!.isNotEmpty)
          'app_version': appVersion,
      };
}
