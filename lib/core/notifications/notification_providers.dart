import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_notification.dart';
import 'notification_service.dart';

/// Singleton-ish [NotificationService] for the lifetime of the Riverpod
/// container. Initialisation is performed eagerly in `main.dart` before
/// `runApp`, so consumers can assume the service is ready.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// One-shot fetch of the current FCM token. The login screen reads this
/// when sending OTP requests so the backend can target the device for push
/// delivery (`auth.send-otp` accepts `device_token`).
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getToken();
});

/// Continuous stream of incoming notifications (foreground / opened-from-bg
/// / opened-from-terminated / tapped-local). Subscribe to this from a
/// router-aware widget to drive deep links.
final notificationStreamProvider = StreamProvider<AppNotification>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.events;
});

/// Live FCM token-refresh stream. Wire to an authenticated `PUT /me/device`
/// call later so the backend always has the freshest token.
final fcmTokenRefreshProvider = StreamProvider<String>((ref) {
  return ref.watch(notificationServiceProvider).onTokenRefresh;
});
