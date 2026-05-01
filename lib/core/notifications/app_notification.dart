import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

/// UI-friendly representation of any notification we receive — whether from
/// FCM (foreground/background/terminated) or a tapped local notification.
///
/// Keeping a single shape makes it easy for the rest of the app to listen on
/// one stream regardless of where the message originated.
class AppNotification {
  const AppNotification({
    this.title,
    this.body,
    this.data = const {},
    this.opened = false,
  });

  /// Notification headline (`notification.title` from FCM).
  final String? title;

  /// Notification body text (`notification.body` from FCM).
  final String? body;

  /// Free-form key/value payload — used for routing inside the app
  /// (e.g. `{ "screen": "transactions", "id": "tx_123" }`).
  final Map<String, dynamic> data;

  /// `true` when the user tapped the notification to open the app
  /// (vs. just receiving it while the app was already in the foreground).
  final bool opened;

  factory AppNotification.fromRemoteMessage(
    RemoteMessage message, {
    bool opened = false,
  }) {
    return AppNotification(
      title: message.notification?.title,
      body: message.notification?.body,
      data: Map<String, dynamic>.from(message.data),
      opened: opened,
    );
  }

  /// Decodes a payload string previously serialised by the local
  /// notifications plugin. Returns an empty notification on parse failure.
  factory AppNotification.fromLocalPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const AppNotification(opened: true);
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return AppNotification(
          data: decoded,
          opened: true,
        );
      }
    } catch (_) {
      // Fall through and return an empty notification.
    }
    return const AppNotification(opened: true);
  }

  /// Encoded form suitable for storing in `LocalNotification.payload`.
  String? encodePayload() {
    if (data.isEmpty) return null;
    return jsonEncode(data);
  }

  @override
  String toString() =>
      'AppNotification(title: $title, body: $body, data: $data, opened: $opened)';
}
