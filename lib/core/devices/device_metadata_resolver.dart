import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/app_constants.dart';
import '../notifications/notification_providers.dart';
import '../notifications/notification_service.dart';
import '../storage/local_storage.dart';
import '../storage/storage_keys.dart';

/// Snapshot of everything the backend needs to identify *this* device on
/// any `device_token`-aware endpoint (`/devices/register*`, `/auth/verify-otp`,
/// `/auth/register`, `/auth/firebase`, …).
///
/// `token` is `null` when Firebase hasn't issued an FCM token yet — callers
/// must decide whether to skip the device fields, retry later, or send the
/// request without push targeting.
@immutable
class DeviceMetadata {
  const DeviceMetadata({
    required this.platform,
    this.token,
    this.locale,
    this.deviceName,
    this.deviceModel,
    this.appVersion,
  });

  /// FCM registration token. `null` when the token isn't ready yet.
  final String? token;

  /// `android` | `ios` | `web` (the only values the backend accepts).
  final String platform;

  /// User-facing locale code: `ar` or `en`.
  final String? locale;

  /// Human-readable device name, e.g. `"Samsung Galaxy S21"`.
  final String? deviceName;

  /// Device model identifier, e.g. `"SM-G991B"`.
  final String? deviceModel;

  /// App version + build, e.g. `"1.0.0+1"`.
  final String? appVersion;

  /// Convenience: drops `null`/empty fields and returns the JSON shape the
  /// backend expects when you want to splat device info into another body
  /// (e.g. `verify-otp`, `register`).
  Map<String, dynamic> toAuthBodyJson() {
    final map = <String, dynamic>{'platform': platform};
    if (token != null && token!.isNotEmpty) map['device_token'] = token;
    if (locale != null && locale!.isNotEmpty) map['locale'] = locale;
    if (deviceName != null && deviceName!.isNotEmpty) {
      map['device_name'] = deviceName;
    }
    if (deviceModel != null && deviceModel!.isNotEmpty) {
      map['device_model'] = deviceModel;
    }
    if (appVersion != null && appVersion!.isNotEmpty) {
      map['app_version'] = appVersion;
    }
    return map;
  }
}

/// Single source of truth for collecting platform / locale / device-info /
/// FCM-token metadata. Used by:
///
///  * `GuestDeviceService` and `AuthenticatedDeviceService` for
///    `/devices/register*`.
///  * The auth flow (`verify-otp`, `register`, `firebase`) so the device is
///    auto-linked to the user account on first contact.
///
/// Every method swallows its own errors and falls back to `null` so a
/// flaky `device_info_plus` call can never crash the auth flow.
class DeviceMetadataResolver {
  DeviceMetadataResolver({
    required NotificationService notifications,
    required LocalStorage storage,
  })  : _notifications = notifications,
        _storage = storage;

  final NotificationService _notifications;
  final LocalStorage _storage;

  /// Gathers everything in parallel. Pass [includeToken]=`false` to skip the
  /// FCM lookup (useful when the caller already has a token in hand).
  Future<DeviceMetadata> resolve({bool includeToken = true}) async {
    final platform = _resolvePlatform();
    final locale = _resolveLocale();
    final results = await Future.wait<Object?>([
      includeToken ? _resolveToken() : Future<String?>.value(null),
      _resolveAppVersion(),
      _resolveDeviceMeta(),
    ]);
    final token = results[0] as String?;
    final appVersion = results[1] as String?;
    final (deviceName, deviceModel) = results[2] as (String?, String?);

    return DeviceMetadata(
      token: token,
      platform: platform,
      locale: locale,
      deviceName: deviceName,
      deviceModel: deviceModel,
      appVersion: appVersion,
    );
  }

  String _resolvePlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    // Backend only accepts android | ios | web — fall back to `web` for
    // desktop targets so the request still validates.
    return 'web';
  }

  String _resolveLocale() {
    final saved = _storage.readString(StorageKeys.locale);
    if (saved != null && AppConstants.supportedLocales.contains(saved)) {
      return saved;
    }
    return AppConstants.defaultLocale;
  }

  Future<String?> _resolveToken() async {
    try {
      final token = await _notifications.getToken();
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (e) {
      debugPrint('[DeviceMeta] FCM getToken failed: $e');
      return null;
    }
  }

  Future<String?> _resolveAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version;
      final b = info.buildNumber;
      if (v.isEmpty) return null;
      return b.isEmpty ? v : '$v+$b';
    } catch (e) {
      debugPrint('[DeviceMeta] PackageInfo failed: $e');
      return null;
    }
  }

  /// Returns `(deviceName, deviceModel)` — best-effort, never throws.
  Future<(String?, String?)> _resolveDeviceMeta() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await info.webBrowserInfo;
        return (web.browserName.name, web.userAgent);
      }
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final name = [a.manufacturer, a.model]
            .where((s) => s.trim().isNotEmpty)
            .join(' ');
        return (name.isEmpty ? null : name, a.model);
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return (i.name, i.utsname.machine);
      }
    } catch (e) {
      debugPrint('[DeviceMeta] DeviceInfo failed: $e');
    }
    return (null, null);
  }
}

/// Singleton resolver. Cheap to instantiate but stateful enough (caches
/// `_currentLocale` reads, etc.) that one shared instance is preferable.
final deviceMetadataResolverProvider = Provider<DeviceMetadataResolver>((ref) {
  return DeviceMetadataResolver(
    notifications: ref.watch(notificationServiceProvider),
    storage: ref.watch(localStorageProvider),
  );
});
