import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../storage/storage_keys.dart';
import 'platform_locale.dart';

/// Holds the active [Locale] and persists the user's choice.
///
/// Cold start is read-only on the platform side: we trust whatever the
/// previous session wrote (Android per-app locale + the activity-alias state
/// applied by `MainActivity.onCreate`) and only update Flutter's own
/// in-memory locale here. That avoids the "first launch / language switch
/// crashes the app" bug on Android 12, where pushing the locale into
/// `AppCompatDelegate` triggered an activity recreation at the same moment we
/// were toggling the LAUNCHER component the activity was running through —
/// killing the process on Samsung devices.
///
/// Explicit user changes (via [setLocale]/[toggle]) still forward into the
/// Android per-app locale store so notifications, recents and the launcher
/// label (Android 13+) update too. The launcher-icon alias swap on older
/// Android versions is handled natively in `MainActivity.onCreate` on the
/// next cold start — never mid-session — which keeps the swap from
/// disabling the component the foreground activity is running through.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _restore();
    return const Locale(AppConstants.defaultLocale);
  }

  /// Restores the persisted in-app locale into Flutter state. Intentionally
  /// does NOT push to the platform: the OS already remembers the per-app
  /// locale across launches, and replaying the call here used to recreate
  /// the activity on every cold start (which collided with the alias swap
  /// and crashed the process).
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(StorageKeys.locale);
    if (code != null && AppConstants.supportedLocales.contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!AppConstants.supportedLocales.contains(locale.languageCode)) return;
    if (state.languageCode == locale.languageCode) return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.locale, locale.languageCode);
    // Forward the choice into Android's per-app locale store so notifications
    // and (on Android 13+) the launcher label update. The launcher-icon
    // activity-alias swap is performed by `MainActivity.onCreate` on the
    // next cold start — doing it now would risk killing the foreground
    // activity, which is exactly what the user reported.
    await PlatformLocale.setApplicationLocale(locale.languageCode);
  }

  Future<void> toggle() async {
    final next = state.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    await setLocale(next);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
