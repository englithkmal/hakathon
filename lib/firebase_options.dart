// Manually authored Firebase options.
//
// Mirrors what `flutterfire configure` would generate, but written by hand
// because we received the Android `google-services.json` from the team
// without running the CLI. iOS / web / macOS values are missing on purpose —
// fill them in once we register those platforms in Firebase Console
// (Project: molly-9a63d) and download the relevant config files.
//
// SAFETY: these strings are public client identifiers, NOT secrets — Firebase
// is designed for them to ship with the app binary. Real security lives in
// Firebase Security Rules + App Check on the backend.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase has not been configured for the web platform. '
        'Add the web app in Firebase Console → Project Settings → Your apps, '
        'then paste the values into DefaultFirebaseOptions.web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Firebase has not been configured for iOS. Register the iOS app '
          'in Firebase Console and add the GoogleService-Info.plist before '
          'shipping iOS builds.',
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions has no configuration for '
          '$defaultTargetPlatform yet.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBlMHVK1df_XqAe2SBu5h85TNqFV1lgG7M',
    appId: '1:128413572219:android:e29a9c857b6678932516de',
    messagingSenderId: '128413572219',
    projectId: 'molly-9a63d',
    storageBucket: 'molly-9a63d.firebasestorage.app',
  );
}
