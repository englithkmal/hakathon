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
import '../data/models/register_guest_device_body.dart';

/// Orchestrates the guest-device registration flow.
///
/// Hits `POST /devices/register-guest` so the backend can target this
/// device for broadcast notifications even before (or without) login.
/// Designed to be fired-and-forgotten from `main.dart`:
///
/// * Idempotent — skips the network call if the same FCM token was already
///   registered on a previous launch.
/// * Resilient — every failure (no token yet, server down, malformed
///   response, etc.) is logged but never re-thrown. We retry next launch.
/// * Auto-refresh — listens to FCM `onTokenRefresh` so when Firebase
///   rotates the token we re-register transparently.
class GuestDeviceService {
  GuestDeviceService({
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
  bool _started = false;

  /// Boots the registration flow. Safe to call multiple times — only the
  /// first call kicks off work.
  ///
  /// In mock-backend mode this no-ops (the real API isn't reachable).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    debugPrint('[GuestDevice] start()');

    if (AppConstants.useMockBackend) {
      debugPrint('[GuestDevice] mock backend: skipping register-guest.');
      return;
    }

    // Re-register on every token rotation. We deliberately skip the dedup
    // check here because a refresh implies the previous token is invalid.
    _refreshSub = _notifications.onTokenRefresh.listen(
      (token) {
        debugPrint('[GuestDevice] FCM token refreshed → re-registering.');
        _registerInternal(token, force: true);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[GuestDevice] token-refresh stream error: $e\n$st');
      },
    );

    // Fire the first registration without blocking the caller.
    unawaited(_registerOnceWithRetry());
  }

  /// Public re-entry point — useful if some flow (e.g. permission granted
  /// after a denial) wants to retry registration on demand.
  Future<void> registerNow() => _registerOnceWithRetry();

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
  }

  // ─────────────────────────── Internals ────────────────────────────

  /// Tries to fetch the FCM token a few times with a short delay between
  /// attempts. On a brand-new install Firebase needs a moment to provision
  /// the token, so a bare `getToken()` can return `null` on the very first
  /// run.
  Future<void> _registerOnceWithRetry() async {
    const maxAttempts = 5;
    const delay = Duration(seconds: 2);
    for (var i = 0; i < maxAttempts; i++) {
      final token = await _notifications.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint(
          '[GuestDevice] got FCM token (attempt ${i + 1}); '
          'preview=${token.substring(0, token.length.clamp(0, 12))}…',
        );
        await _registerInternal(token);
        return;
      }
      debugPrint(
        '[GuestDevice] FCM token not ready (attempt ${i + 1}/$maxAttempts).',
      );
      if (i < maxAttempts - 1) {
        await Future<void>.delayed(delay);
      }
    }
    debugPrint(
      '[GuestDevice] FCM token still unavailable after retries — '
      'will try again on next launch / token-refresh.',
    );
  }

  Future<void> _registerInternal(String token, {bool force = false}) async {
    try {
      if (!force) {
        final last = _storage.readString(StorageKeys.guestRegisteredToken);
        if (last == token) {
          if (kDebugMode) {
            debugPrint(
              '[GuestDevice] token already registered, skipping.',
            );
          }
          return;
        }
      }

      // Fetch everything except the token (we already have it).
      final meta = await _metadata.resolve(includeToken: false);
      final body = RegisterGuestDeviceBody(
        token: token,
        platform: meta.platform,
        deviceName: meta.deviceName,
        deviceModel: meta.deviceModel,
        appVersion: meta.appVersion,
        locale: meta.locale,
      );
      await _remote.registerGuest(body);
      await _storage.writeString(StorageKeys.guestRegisteredToken, token);
      if (kDebugMode) {
        debugPrint(
          '[GuestDevice] register-guest OK '
          '(platform=${body.platform}, locale=${body.locale}).',
        );
      }
    } catch (e, st) {
      // Never crash the app — we'll retry on the next cold start or token
      // refresh. The marker prefix makes the message easy to search for in
      // a noisy IDE Run console.
      debugPrint('═════════════════════════════════════════════');
      debugPrint('[GuestDevice] ❌ register-guest FAILED');
      debugPrint('  type:    ${e.runtimeType}');
      debugPrint('  message: $e');
      debugPrint('═════════════════════════════════════════════');
      debugPrint('$st');
    }
  }
}

/// Provides a singleton [GuestDeviceService]. Wired up in `main.dart` so
/// `start()` runs before the first frame.
final guestDeviceServiceProvider = Provider<GuestDeviceService>((ref) {
  final service = GuestDeviceService(
    remote: ref.watch(deviceRemoteDataSourceProvider),
    storage: ref.watch(localStorageProvider),
    notifications: ref.watch(notificationServiceProvider),
    metadata: ref.watch(deviceMetadataResolverProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
