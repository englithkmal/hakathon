import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/devices/device_metadata_resolver.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../data/data_sources/device_remote_data_source.dart';
import '../data/models/register_device_body.dart';

/// Orchestrates the **authenticated** device-registration flow.
///
/// Sister to [GuestDeviceService] (`/devices/register-guest`). Once the user
/// is logged in we additionally call `POST /devices/register` so the backend
/// can resolve `device.user_id` for the FCM token and start delivering
/// per-user pushes (alerts, tips, transaction reminders, etc.). Without
/// this call only:
///
///  * **OTP pushes** — the FCM token is sent *inline* in the `send-otp`
///    request body, so the backend doesn't need a `devices` row to deliver
///    them. This is why OTP keeps working while everything else stays silent.
///  * **Guest broadcasts** — anything addressed to the guest pool from
///    `/devices/register-guest`.
///
/// Reach this device for ANY user-targeted notification.
///
/// Designed to be driven by an `authProvider` listener:
///
///   * Call [onAuthenticated] every time the user lands in the
///     `AuthAuthenticated` state. Idempotent — a `<userId>:<token>` cache
///     short-circuits the call when nothing has changed.
///   * Call [onLoggedOut] from the auth notifier just before clearing the
///     session, so we can `POST /devices/unregister` while we still have a
///     valid Bearer token.
class AuthenticatedDeviceService {
  AuthenticatedDeviceService({
    required DeviceRemoteDataSource remote,
    required LocalStorage storage,
    required NotificationService notifications,
    required DeviceMetadataResolver metadata,
  })  : _remote = remote,
        _storage = storage,
        _notifications = notifications,
        _metadata = metadata;

  final DeviceRemoteDataSource _remote;
  final LocalStorage _storage;
  final NotificationService _notifications;
  final DeviceMetadataResolver _metadata;

  StreamSubscription<String>? _refreshSub;
  String? _currentUserId;
  bool _started = false;

  /// Wires up the FCM token-refresh listener. Safe to call repeatedly —
  /// only the first call sets up the subscription.
  ///
  /// In mock-backend mode this no-ops (the real API isn't reachable).
  void start() {
    if (_started) return;
    _started = true;

    if (AppConstants.useMockBackend) {
      debugPrint('[AuthedDevice] mock backend: skipping listener wiring.');
      return;
    }

    _refreshSub = _notifications.onTokenRefresh.listen(
      (token) {
        final uid = _currentUserId;
        if (uid == null) {
          debugPrint(
            '[AuthedDevice] token refreshed but no user is logged in — '
            'guest service will pick it up.',
          );
          return;
        }
        debugPrint(
          '[AuthedDevice] FCM token refreshed → re-registering for user=$uid',
        );
        _registerInternal(uid, token, force: true);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[AuthedDevice] token-refresh stream error: $e\n$st');
      },
    );
  }

  /// Hook this from the auth listener whenever the state transitions into
  /// (or refreshes inside) [AuthAuthenticated]. Idempotent.
  Future<void> onAuthenticated(String userId) async {
    if (AppConstants.useMockBackend) return;
    if (userId.isEmpty) return;
    _currentUserId = userId;
    await _registerOnceWithRetry(userId);
  }

  /// Hook this from the auth listener BEFORE the auth notifier wipes the
  /// session — we need the Bearer token to be present to call
  /// `/devices/unregister`. Best-effort: any failure is logged and
  /// swallowed so logout always proceeds.
  Future<void> onLoggedOut() async {
    if (AppConstants.useMockBackend) return;

    final token = await _notifications.getToken();
    _currentUserId = null;
    // Always wipe the cached marker so the next login re-registers, even if
    // the unregister call below fails.
    await _storage.remove(StorageKeys.authedRegisteredToken);

    if (token == null || token.isEmpty) {
      debugPrint('[AuthedDevice] logout: no FCM token to unregister.');
      return;
    }
    try {
      await _remote.unregisterDevice(UnregisterDeviceBody(token: token));
      debugPrint('[AuthedDevice] /devices/unregister OK.');
    } catch (e) {
      debugPrint('[AuthedDevice] /devices/unregister failed: $e');
    }
  }

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
  }

  // ─────────────────────────── Internals ────────────────────────────

  /// Tries to fetch the FCM token a few times with a short delay between
  /// attempts. On a fresh install Firebase needs a moment to provision the
  /// token, so a bare `getToken()` can return `null` on the very first run
  /// (especially right after the user accepts the notifications prompt).
  Future<void> _registerOnceWithRetry(String userId) async {
    const maxAttempts = 5;
    const delay = Duration(seconds: 2);
    for (var i = 0; i < maxAttempts; i++) {
      final token = await _notifications.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint(
          '[AuthedDevice] got FCM token (attempt ${i + 1}); '
          'preview=${token.substring(0, token.length.clamp(0, 12))}…',
        );
        await _registerInternal(userId, token);
        return;
      }
      debugPrint(
        '[AuthedDevice] FCM token not ready (attempt ${i + 1}/$maxAttempts).',
      );
      if (i < maxAttempts - 1) {
        await Future<void>.delayed(delay);
      }
    }
    debugPrint(
      '[AuthedDevice] FCM token still unavailable after retries — '
      'will retry on next login / token-refresh.',
    );
  }

  Future<void> _registerInternal(
    String userId,
    String token, {
    bool force = false,
  }) async {
    final marker = '$userId:$token';
    try {
      if (!force) {
        final last = _storage.readString(StorageKeys.authedRegisteredToken);
        if (last == marker) {
          if (kDebugMode) {
            debugPrint(
              '[AuthedDevice] same user+token already registered — skipping.',
            );
          }
          return;
        }
      }

      // Fetch everything except the token (we already have it).
      final meta = await _metadata.resolve(includeToken: false);
      final body = RegisterDeviceBody(
        token: token,
        platform: meta.platform,
        deviceName: meta.deviceName,
        deviceModel: meta.deviceModel,
        appVersion: meta.appVersion,
        locale: meta.locale,
      );
      await _remote.registerDevice(body);
      await _storage.writeString(StorageKeys.authedRegisteredToken, marker);
      debugPrint(
        '═════════════════════════════════════════════',
      );
      debugPrint(
        '[AuthedDevice] ✅ /devices/register OK '
        '(user=$userId, platform=${body.platform}, locale=${body.locale}).',
      );
      debugPrint(
        '═════════════════════════════════════════════',
      );
    } catch (e, st) {
      // Don't crash the auth flow. A failure here just means user-targeted
      // pushes won't reach this device until the next retry (next login,
      // token refresh, or a manual call to [onAuthenticated]).
      debugPrint('═════════════════════════════════════════════');
      debugPrint('[AuthedDevice] ❌ /devices/register FAILED');
      debugPrint('  user:    $userId');
      debugPrint('  type:    ${e.runtimeType}');
      debugPrint('  message: $e');
      debugPrint('═════════════════════════════════════════════');
      debugPrint('$st');
    }
  }
}

/// Singleton [AuthenticatedDeviceService]. Wired up from `app.dart` via a
/// listener on `authProvider`.
final authenticatedDeviceServiceProvider =
    Provider<AuthenticatedDeviceService>((ref) {
  final service = AuthenticatedDeviceService(
    remote: ref.watch(deviceRemoteDataSourceProvider),
    storage: ref.watch(localStorageProvider),
    notifications: ref.watch(notificationServiceProvider),
    metadata: ref.watch(deviceMetadataResolverProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
