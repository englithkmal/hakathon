import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import '../storage/storage_keys.dart';

/// Attaches the bearer token (when present) and a couple of common headers
/// to every outgoing request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage);

  final SecureStorage _secureStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra['skipAuth'] == true;

    if (!skipAuth) {
      final token = await _secureStorage.read(StorageKeys.authToken);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    options.headers.putIfAbsent('Accept', () => 'application/json');
    handler.next(options);
  }
}
