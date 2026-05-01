import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../storage/storage_keys.dart';

/// Adds `Accept-Language` to every outgoing request based on the user's
/// active locale. Backend uses this to localise alerts, tips and category
/// names (`name_ar` vs `name_en`).
class LocaleInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!options.headers.containsKey('Accept-Language')) {
      final code = await _currentLanguage();
      options.headers['Accept-Language'] = code;
    }
    handler.next(options);
  }

  Future<String> _currentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(StorageKeys.locale);
      if (stored != null && AppConstants.supportedLocales.contains(stored)) {
        return stored;
      }
    } catch (_) {}
    return AppConstants.defaultLocale;
  }
}
