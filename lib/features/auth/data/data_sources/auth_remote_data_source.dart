import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../models/auth_session.dart';
import '../models/login_request.dart';
import '../models/otp_request_info.dart';
import '../models/register_request.dart';
import '../models/user_model.dart';
import '../models/verify_otp_result.dart';

/// Speaks to the Waffer backend for everything auth-related.
///
/// Throws [AppException]s — never raw [DioException]s — so the repository
/// layer doesn't need to know we're using Dio.
abstract class AuthRemoteDataSource {
  Future<OtpRequestInfo> sendOtp(RequestOtpBody body);
  Future<VerifyOtpResult> verifyOtp(VerifyOtpBody body);
  Future<AuthSession> register(RegisterBody body);
  Future<UserModel> me();

  /// `PUT /auth/profile`. Pass only the fields the user actually
  /// changed — the backend treats `null`/missing keys as "leave it".
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    num? monthlyIncome,
    String? currency,
    String? language,
  });

  Future<void> logout();
  Future<void> logoutAll();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<OtpRequestInfo> sendOtp(RequestOtpBody body) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.sendOtp,
        data: body.toJson(),
        options: Options(extra: {'skipAuth': true}),
      );
      final data = _unwrapData(response.data, endpoint: 'send-otp');
      return OtpRequestInfo.fromJson(data);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<VerifyOtpResult> verifyOtp(VerifyOtpBody body) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.verifyOtp,
        data: body.toJson(),
        options: Options(extra: {'skipAuth': true}),
      );
      final data = _unwrapData(response.data, endpoint: 'verify-otp');
      // New-user branch → backend returns `{ verified: true, is_new_user: true }`.
      final isNewUser = data['is_new_user'] == true;
      if (isNewUser) {
        return VerifyOtpNeedsRegistration(
          phoneE164: body.phoneE164,
          code: body.code,
        );
      }
      // Existing-user branch → `{ user, token, is_new_user: false }`.
      final session = AuthSession.fromJson(data);
      if (session.accessToken.isEmpty) {
        throw const ServerException(
          message: 'verify-otp succeeded but returned no token.',
        );
      }
      return VerifyOtpAuthenticated(session);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<AuthSession> register(RegisterBody body) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: body.toJson(),
        options: Options(extra: {'skipAuth': true}),
      );
      final data = _unwrapData(response.data, endpoint: 'register');
      final session = AuthSession.fromJson(data);
      if (session.accessToken.isEmpty) {
        throw const ServerException(
          message: 'register succeeded but returned no token.',
        );
      }
      return session;
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<UserModel> me() async {
    try {
      final response = await _dio.get(ApiEndpoints.me);
      final data = _unwrapData(response.data, endpoint: 'me');
      // `/auth/me` typically returns `data.user`. Fall back to using `data`
      // itself if the backend ever flattens the shape.
      final userMap = (data['user'] is Map<String, dynamic>)
          ? data['user'] as Map<String, dynamic>
          : data;
      return UserModel.fromJson(userMap);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    num? monthlyIncome,
    String? currency,
    String? language,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.profile,
        data: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (monthlyIncome != null) 'monthly_income': monthlyIncome,
          if (currency != null) 'currency': currency,
          if (language != null) 'language': language,
        },
      );
      final data = _unwrapData(response.data, endpoint: 'profile');
      // Same un-wrapping rules as `me`: prefer `data.user`, fall back
      // to `data` itself if Laravel flattens the shape.
      final userMap = (data['user'] is Map<String, dynamic>)
          ? data['user'] as Map<String, dynamic>
          : data;
      return UserModel.fromJson(userMap);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<void> logoutAll() async {
    try {
      await _dio.post(ApiEndpoints.logoutAll);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Strips the `{ success, message, data }` envelope and returns the inner
  /// `data` map. If the backend ever returns the payload un-wrapped, we
  /// assume the whole body is the payload.
  Map<String, dynamic> _unwrapData(
    Object? body, {
    required String endpoint,
  }) {
    if (body is! Map<String, dynamic>) {
      throw ServerException(
        message: 'Unexpected $endpoint response shape.',
      );
    }
    final inner = body['data'];
    if (inner is Map<String, dynamic>) return inner;
    // Some Laravel resources skip the wrapping when `data` is empty/null.
    return body;
  }

  /// `ErrorInterceptor` puts an [AppException] in `DioException.error`. If
  /// for some reason that didn't happen, fall back to mapping it here.
  AppException _unwrap(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    return mapDioException(e);
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(dioProvider));
});
