/// Request body for `POST /api/v1/devices/register` (authenticated).
///
/// Links an FCM token to the currently-logged-in user account so the backend
/// can target push notifications by `user_id`. The auth Bearer token on the
/// request identifies the user — the body just describes the device.
///
/// Mirrors [RegisterGuestDeviceBody] field-for-field; the only difference
/// is the endpoint and the auth header.
class RegisterDeviceBody {
  const RegisterDeviceBody({
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

/// Request body for `POST /api/v1/devices/unregister`.
///
/// Removes a single FCM token from the backend so the device stops receiving
/// pushes for the user that's logging out. We send the token explicitly
/// (rather than relying on the backend to wipe everything for the user) so
/// the user's other devices keep getting notifications.
class UnregisterDeviceBody {
  const UnregisterDeviceBody({required this.token});

  final String token;

  Map<String, dynamic> toJson() => {'token': token};
}
