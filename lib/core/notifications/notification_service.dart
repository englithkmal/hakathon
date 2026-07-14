import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_notification.dart';

/// Single source of truth for every notification path in the app.
///
/// Responsibilities:
/// * Request notification permission (Android 13+ / iOS).
/// * Configure a local-notifications channel and surface FCM messages while
///   the app is in the **foreground** (FCM doesn't auto-display those).
/// * Bridge FCM events (foreground / background-tap / cold-start-tap) +
///   tapped local notifications into a single [Stream<AppNotification>].
/// * Expose the FCM `device_token` so the auth flow can register it
///   server-side as `device_token` per the Waffer API spec.
class NotificationService {
  NotificationService();

  // Channel id is referenced from native code (and FCM payloads) so it must
  // stay stable across releases.
  static const _channelId = 'wafferapp_default';
  static const _channelName = 'WafferApp Notifications';
  static const _channelDescription =
      'General notifications including OTPs, alerts, and reminders.';

  // Resource identifiers must match files in `android/app/src/main/res/`.
  // Status-bar icon must be a white-on-transparent silhouette per Android.
  static const _androidNotificationIcon = '@drawable/ic_stat_notification';
  // Brand-colored tint applied to the silhouette (Waffer primary —
  // Forest Green `#0D5237`, matches the Figma design).
  static const Color _androidNotificationColor = Color(0xFF0D5237);

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final StreamController<AppNotification> _events =
      StreamController<AppNotification>.broadcast();

  /// Stream of every notification surfaced to the app — whether it arrived
  /// via FCM or a tapped local notification.
  Stream<AppNotification> get events => _events.stream;

  bool _initialized = false;

  /// Idempotent — safe to call repeatedly during app start-up.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Each step is wrapped so that one failure (e.g. a missing icon resource
    // on a stale APK before a full rebuild) doesn't kill the whole pipeline
    // and prevent FCM tokens / listeners from being set up.
    await _safe('requestPermission', _requestPermission);
    await _safe('initLocalNotifications', _initLocalNotifications);
    await _safe('configureForeground', _configureForegroundPresentation);
    try {
      _bindFcmListeners();
    } catch (e, st) {
      debugPrint('[Notifications] bindFcmListeners failed: $e\n$st');
    }
    await _safe('checkColdStartLaunch', _checkColdStartLaunch);
  }

  Future<void> _safe(String label, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e, st) {
      debugPrint('[Notifications] $label failed: $e\n$st');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) {
      debugPrint(
        '[FCM] permission status=${settings.authorizationStatus.name}',
      );
    }
  }

  Future<void> _initLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings(_androidNotificationIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleLocalTap,
    );

    // Pre-create the high-importance Android channel so heads-up
    // notifications work as soon as the first push arrives.
    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    // Android 13+ requires a runtime POST_NOTIFICATIONS prompt. Trigger it
    // here in addition to the FCM permission request (the FCM plugin only
    // handles iOS-style prompts).
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _configureForegroundPresentation() async {
    // iOS: ask the system to show banners + sound while the app is open.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _bindFcmListeners() {
    // Foreground: surface a local notification (FCM doesn't auto-display
    // notifications while the app is open) AND emit on the stream.
    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundLocal(message);
      _events.add(AppNotification.fromRemoteMessage(message));
    });

    // Background → user tapped the system notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _events.add(
        AppNotification.fromRemoteMessage(message, opened: true),
      );
    });
  }

  Future<void> _checkColdStartLaunch() async {
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      _events.add(
        AppNotification.fromRemoteMessage(initial, opened: true),
      );
    }
  }

  void _handleLocalTap(NotificationResponse response) {
    _events.add(AppNotification.fromLocalPayload(response.payload));
  }

  void _showForegroundLocal(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return; // Data-only message — let the listener route it.

    final payload = AppNotification.fromRemoteMessage(message).encodePayload();

    _local.show(
      // Stable-ish id: hashCode collapses to 32-bit which is what Android wants.
      id: message.messageId?.hashCode ?? notif.hashCode,
      title: notif.title,
      body: notif.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: _androidNotificationIcon,
          color: _androidNotificationColor,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ─────────────────────────── Public API ────────────────────────────

  /// Returns the current FCM registration token. May be `null` on first run
  /// before the token has been provisioned, or if the user denied
  /// permissions.
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e, st) {
      debugPrint('[FCM] getToken failed: $e\n$st');
      return null;
    }
  }

  /// Stream of token-refresh events — wire this to an authenticated API
  /// call so the backend always has the current `device_token`.
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  Future<void> subscribeToTopic(String topic) => _fcm.subscribeToTopic(topic);
  Future<void> unsubscribeFromTopic(String topic) =>
      _fcm.unsubscribeFromTopic(topic);

  /// Clears the FCM token — call this on logout so the device stops
  /// receiving pushes for the previous user.
  Future<void> deleteToken() => _fcm.deleteToken();

  Future<void> dispose() async {
    await _events.close();
  }
}
