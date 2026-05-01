import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';
import 'api_client.dart';

/// Singleton-per-ProviderScope [Dio] instance, ready for the data layer.
///
/// Reads the secure token storage so the [AuthInterceptor] can attach a
/// bearer token automatically on every request.
final dioProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ApiClient.create(secureStorage: secureStorage);
});
