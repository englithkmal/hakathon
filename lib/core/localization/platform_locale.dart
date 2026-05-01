import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge between [LocaleNotifier] and Android's per-app locale store.
///
/// On Android 13+ the system shows a per-app language picker
/// (Settings → Apps → Waffer → Language) and uses that choice to pick the
/// right `values-<locale>/strings.xml` bundle for surfaces shown OUTSIDE the
/// Flutter UI — notably the launcher label (`Waffer` vs. `وفر`),
/// notifications, and the recent-apps drawer.
///
/// Calling [setApplicationLocale] forwards the user's in-app language pick
/// into that store so all of those surfaces update along with the app UI.
/// On older Android versions (≤12) the launcher label still follows the
/// device system language and instead is updated via the activity-alias swap
/// in `MainActivity.onCreate` on the next cold start. On non-Android
/// platforms the method is a no-op.
class PlatformLocale {
  PlatformLocale._();

  static const _channel = MethodChannel('wafferapp/locale');

  /// Pushes [languageTag] (e.g. `en`, `ar`) into the platform's per-app
  /// locale slot. Errors are swallowed and logged in debug — failing to
  /// sync the launcher label should never crash the app.
  static Future<void> setApplicationLocale(String languageTag) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        'setApplicationLocale',
        {'languageTag': languageTag},
      );
    } catch (e, st) {
      debugPrint('PlatformLocale.setApplicationLocale failed: $e\n$st');
    }
  }
}
