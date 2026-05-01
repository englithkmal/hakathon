/// Body for `POST /auth/send-otp`.
///
/// `phone` must be in E.164 format (e.g. `+966555555555`). The remaining
/// fields are optional but help the backend deliver the OTP via push and
/// localise the message.
class RequestOtpBody {
  const RequestOtpBody({
    required this.phoneE164,
    this.deviceToken,
    this.platform,
    this.locale,
  });

  final String phoneE164;
  final String? deviceToken;
  final String? platform; // android | ios | web
  final String? locale; // ar | en

  Map<String, dynamic> toJson() => {
        'phone': phoneE164,
        if (deviceToken != null) 'device_token': deviceToken,
        if (platform != null) 'platform': platform,
        if (locale != null) 'locale': locale,
      };
}

/// Body for `POST /auth/verify-otp`.
///
/// In addition to the obvious `phone` + `code` pair, the backend expects
/// the same `device_token` / `platform` / `locale` / `device_name` /
/// `device_model` / `app_version` fields used by `/devices/register-guest`
/// so it can transparently link the device to the freshly-authenticated
/// user account. Without this, only OTP pushes and guest broadcasts reach
/// the device — every user-targeted notification (budget alerts, monthly
/// summary, goal pace, etc.) silently disappears.
class VerifyOtpBody {
  const VerifyOtpBody({
    required this.phoneE164,
    required this.code,
    this.deviceToken,
    this.platform,
    this.locale,
    this.deviceName,
    this.deviceModel,
    this.appVersion,
  });

  final String phoneE164;
  final String code;
  final String? deviceToken;
  final String? platform; // android | ios | web
  final String? locale; // ar | en
  final String? deviceName;
  final String? deviceModel;
  final String? appVersion;

  Map<String, dynamic> toJson() => {
        'phone': phoneE164,
        'code': code,
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
