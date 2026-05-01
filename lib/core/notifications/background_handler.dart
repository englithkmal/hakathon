import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Handles FCM messages that arrive while the app is **terminated** or in
/// **background**.
///
/// This function MUST be a **top-level / static** function annotated with
/// `@pragma('vm:entry-point')` so the Flutter engine can call it from a
/// freshly-spawned isolate when the OS wakes the app up to process a push.
///
/// We keep the work here lightweight — Firebase itself displays the
/// notification when the payload contains a `notification` block, so we
/// don't need to manually surface anything. Any heavy lifting (analytics,
/// caching, etc.) should be added cautiously: this isolate has no widgets,
/// no Riverpod scope, and cannot touch the `BuildContext`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The background isolate doesn't share state with the main isolate, so we
  // need to (re)initialise Firebase here before touching any FCM API.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    debugPrint(
      '[FCM bg] id=${message.messageId} '
      'title=${message.notification?.title} '
      'data=${message.data}',
    );
  }
}
