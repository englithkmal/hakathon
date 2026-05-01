import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';
import 'locale_interceptor.dart';

/// Builds a [Dio] instance pre-wired with our interceptor stack.
///
/// Order matters:
///   1. [AuthInterceptor] — adds `Authorization` + common headers.
///   2. [LogInterceptor] — pretty prints in debug only.
///   3. [ErrorInterceptor] — normalises errors into [AppException]s.
class ApiClient {
  ApiClient._();

  static Dio create({
    required SecureStorage secureStorage,
    String? baseUrl,
  }) {
    final base = (baseUrl ?? AppConstants.apiBaseUrl).trim();
    final fullBase = base.endsWith('/') ? base : '$base/';
    final resolvedBase = '$fullBase${AppConstants.apiVersion}';

    // Surface the resolved API host on cold-start so a stale APK pointing
    // at the wrong dev host (very common when the dev box has multiple
    // network interfaces, e.g. corp-VPN + Wi-Fi) is obvious from the very
    // first log line instead of after a 20s timeout.
    if (kDebugMode) {
      debugPrint('═════════════════════════════════════════════');
      debugPrint('[ApiClient] base URL → $resolvedBase');
      debugPrint('═════════════════════════════════════════════');
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: resolvedBase,
        connectTimeout: AppConstants.apiConnectTimeout,
        receiveTimeout: AppConstants.apiReceiveTimeout,
        sendTimeout: AppConstants.apiSendTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
        },
        // Let Dio bubble up only real failures; we still inspect statuses
        // ourselves in data sources for richer error mapping.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    dio.interceptors.add(AuthInterceptor(secureStorage));
    dio.interceptors.add(LocaleInterceptor());

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }

    dio.interceptors.add(const ErrorInterceptor());

    return dio;
  }
}
