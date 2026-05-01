import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../models/register_device_body.dart';
import '../models/register_guest_device_body.dart';

/// Speaks to the Waffer `/devices/*` endpoints.
///
/// Throws [AppException]s — never raw [DioException]s — so callers can
/// remain transport-agnostic.
abstract class DeviceRemoteDataSource {
  /// `POST /devices/register-guest` — registers an FCM token for an
  /// unauthenticated device. The backend later auto-links the token to a
  /// user account once [registerDevice] is called with the same token.
  Future<void> registerGuest(RegisterGuestDeviceBody body);

  /// `POST /devices/register` 🔒 — links the current device's FCM token to
  /// the authenticated user account (Bearer token on the request identifies
  /// the user). Required for the backend to deliver per-user notifications
  /// like alerts, tips, transaction reminders, etc. Without this call only
  /// guest broadcasts and OTP pushes (which carry the token in the request
  /// body) reach the device.
  Future<void> registerDevice(RegisterDeviceBody body);

  /// `POST /devices/unregister` 🔒 — removes a single FCM token from the
  /// backend so this device stops receiving pushes for the user that's
  /// logging out. Other devices belonging to the same user are unaffected.
  Future<void> unregisterDevice(UnregisterDeviceBody body);
}

class DeviceRemoteDataSourceImpl implements DeviceRemoteDataSource {
  DeviceRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> registerGuest(RegisterGuestDeviceBody body) async {
    try {
      await _dio.post(
        ApiEndpoints.devicesRegisterGuest,
        data: body.toJson(),
        // No auth header is needed — this endpoint is meant to be hit before
        // the user has logged in.
        options: Options(extra: {'skipAuth': true}),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<void> registerDevice(RegisterDeviceBody body) async {
    try {
      // The Dio AuthInterceptor attaches the Bearer token automatically.
      // We deliberately don't set `skipAuth` so 401 responses bubble up and
      // the caller can retry after a re-login.
      await _dio.post(
        ApiEndpoints.devicesRegister,
        data: body.toJson(),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<void> unregisterDevice(UnregisterDeviceBody body) async {
    try {
      await _dio.post(
        ApiEndpoints.devicesUnregister,
        data: body.toJson(),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// `ErrorInterceptor` puts an [AppException] in `DioException.error`. If
  /// for some reason that didn't happen, fall back to mapping it here.
  AppException _unwrap(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    return mapDioException(e);
  }
}

final deviceRemoteDataSourceProvider = Provider<DeviceRemoteDataSource>((ref) {
  return DeviceRemoteDataSourceImpl(ref.watch(dioProvider));
});
