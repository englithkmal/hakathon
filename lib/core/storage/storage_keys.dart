/// Keys used with [SharedPreferences] / secure storage.
///
/// Convention:
/// - `app.*` and non-sensitive caches → `LocalStorage` (SharedPreferences).
/// - `auth.token` / `auth.refreshToken` → `SecureStorage`.
class StorageKeys {
  StorageKeys._();

  // ───────── App preferences (LocalStorage) ─────────
  static const String themeMode = 'app.themeMode';
  static const String locale = 'app.locale';
  static const String onboardingDone = 'app.onboardingDone';

  // ───────── Auth (mixed) ─────────
  static const String authToken = 'auth.token'; // secure
  static const String refreshToken = 'auth.refreshToken'; // secure
  static const String userJson = 'auth.user'; // local
  static const String userPhone = 'auth.userPhone'; // local
  static const String tokenExpiresAt = 'auth.tokenExpiresAt'; // local

  // ───────── Devices / FCM (LocalStorage) ─────────
  /// Last FCM token successfully registered with the backend. Used to skip
  /// duplicate `register-guest` calls on every cold start when the token
  /// hasn't rotated.
  static const String guestRegisteredToken = 'devices.guestRegisteredToken';

  /// Last FCM token successfully linked to the currently-authenticated user
  /// via `POST /devices/register`. Composite "<userId>:<token>" so we
  /// re-register whenever the user OR the token changes (login as a
  /// different user, FCM token rotation, etc.) but skip the redundant call
  /// on a normal cold start of the same user with the same token.
  static const String authedRegisteredToken = 'devices.authedRegisteredToken';
}
