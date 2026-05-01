import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notifications/background_handler.dart';
import 'core/notifications/notification_providers.dart';
import 'core/storage/local_storage.dart';
import 'features/devices/application/guest_device_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Connect to the Firebase project (`molly-9a63d`) before any plugin that
  // depends on it (Messaging, Auth, etc.) is touched.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register the FCM background handler. Must happen on the main isolate
  // BEFORE any message can arrive — Flutter wires it up exactly once.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Eagerly initialise SharedPreferences so providers can read it
  // synchronously throughout the app.
  final prefs = await SharedPreferences.getInstance();

  // Build a Riverpod container up-front so we can boot services
  // (notifications) before the first frame paints.
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Kick off notification setup (permissions, channels, listeners) in
  // parallel with the first frame — we don't await it, the UI shouldn't
  // block waiting for the system permission dialog.
  unawaited(container.read(notificationServiceProvider).init());

  // Register this device as a "guest" so the backend can target it for
  // broadcast notifications even before the user logs in. Started in
  // parallel with notification init — the service does its own FCM-token
  // retry loop and only calls the API once a token is available, so it
  // doesn't matter if `init()` is still in flight.
  unawaited(container.read(guestDeviceServiceProvider).start());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WafferApp(),
    ),
  );
}

/// Tiny wrapper to silence the analyzer when intentionally ignoring a Future.
void unawaited(Future<void> _) {}
