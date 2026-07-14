/// Request body for `POST /api/v1/devices/register-guest`.
///
/// Saves an FCM token for an unauthenticated device so it can still receive
/// broadcast notifications. The backend auto-links the device to a user
/// account once `/devices/register` is later called with the same token.
class RegisterGuestDeviceBody {
  const RegisterGuestDeviceBody({
    required this.token,
    required this.platform,
    this.deviceName,
    this.deviceModel,
    this.appVersion,
    this.locale,
  });

  /// FCM registration token (required).
  final String token;

  /// One of `android | ios | web` (required).
  final String platform;

  /// Human-readable device name (e.g. "Samsung Galaxy S21").
  final String? deviceName;

  /// Device model identifier (e.g. "SM-G991B").
  final String? deviceModel;

  /// App version + build (e.g. "1.0.0+1").
  final String? appVersion;

  /// User-facing locale code: `ar` or `en`.
  final String? locale;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'token': token,
      'platform': platform,
    };
    if (deviceName != null && deviceName!.isNotEmpty) {
      map['device_name'] = deviceName;
    }
    if (deviceModel != null && deviceModel!.isNotEmpty) {
      map['device_model'] = deviceModel;
    }
    if (appVersion != null && appVersion!.isNotEmpty) {
      map['app_version'] = appVersion;
    }
    if (locale != null && locale!.isNotEmpty) {
      map['locale'] = locale;
    }
    return map;
  }
}
