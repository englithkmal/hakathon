/// Project-wide constants shared across features.
class AppConstants {
  AppConstants._();

  static const String appName = 'WafferApp';
  static const String defaultLocale = 'ar';
  static const List<String> supportedLocales = ['ar', 'en'];

  static const String defaultCurrency = 'SAR';
  static const String defaultCurrencySymbol = 'ريال';
  static const List<String> supportedCurrencies = [
    'SAR',
    'JOD',
    'USD',
    'AED',
    'EUR',
  ];

  static const Duration shortAnimation = Duration(milliseconds: 180);
  static const Duration defaultAnimation = Duration(milliseconds: 280);
  static const Duration longAnimation = Duration(milliseconds: 450);

  static const double tapScaleDown = 0.98;

  // ───────────────────────────── Networking ─────────────────────────────
  // Single source of truth for the backend host. Just edit this string
  // when you switch networks (office Wi-Fi → home → hotspot, etc.).
  //
  // Quick reference for picking the right value:
  //   • Real Android/iOS device on same Wi-Fi → host's LAN IPv4,
  //     e.g. http://192.168.8.105:8000  (run `ipconfig` to find it)
  //   • Android emulator                   → http://10.0.2.2:8000
  //   • iOS simulator / Web / adb reverse  → http://127.0.0.1:8000
  //
  // After editing, do a full `flutter run` (or hot restart with `R`) —
  // hot reload alone won't pick up `const` changes.
  static const String apiBaseUrl = 'http://192.168.8.105:8000';

  /// Path segment appended to [apiBaseUrl]. Final base = `apiBaseUrl/apiVersion`.
  static const String apiVersion = 'api/v1';

  static const Duration apiConnectTimeout = Duration(seconds: 20);
  static const Duration apiReceiveTimeout = Duration(seconds: 20);
  static const Duration apiSendTimeout = Duration(seconds: 20);

  /// While `true`, the auth flow uses an in-memory mock backend (OTP
  /// `123456`). Flip to `false` once the real backend is reachable.
  static const bool useMockBackend = false;

  /// Seconds before a freshly-issued OTP expires. Used as a safety fallback
  /// when the backend response doesn't carry `expires_in`.
  static const int otpExpirySecondsFallback = 120;

  /// Seconds the user must wait before requesting a new OTP. Used as a
  /// fallback when the backend doesn't send `cooldown_seconds`.
  static const int otpResendCooldownFallback = 60;
}
