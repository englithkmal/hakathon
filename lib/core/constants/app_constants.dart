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

  // ───────────────────────────── Supabase ─────────────────────────────
  // ضع هنا بيانات مشروعك في Supabase:
  //   1. اذهب إلى supabase.com → مشروعك → Settings → API
  //   2. انسخ Project URL و anon key
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';

  /// While `true`, the auth flow uses an in-memory mock backend.
  static const bool useMockBackend = false;

  static const int otpExpirySecondsFallback = 120;
  static const int otpResendCooldownFallback = 60;
}
