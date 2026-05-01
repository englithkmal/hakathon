import '../../../../core/constants/app_constants.dart';
import '../../../../core/devices/device_metadata_resolver.dart';
import '../../../../core/errors/exceptions.dart';
import '../data_sources/auth_local_data_source.dart';
import '../models/auth_session.dart';
import '../models/otp_request_info.dart';
import '../models/user_model.dart';
import '../models/verify_otp_result.dart';
import 'auth_repository.dart';

/// In-memory implementation that mimics the Waffer backend so the UI can
/// be exercised end-to-end without a server.
///
/// The accepted OTP is [mockOtp]. The mock distinguishes "new" vs. "existing"
/// users by phone-number prefix: numbers ending in `9` (last digit) are
/// treated as new users to drive the registration flow during QA.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({required this.local});

  static const String mockOtp = '123456';
  static const Duration mockNetworkDelay = Duration(milliseconds: 600);

  final AuthLocalDataSource local;

  /// Phones that are treated as "new users" by the mock — the verify-otp
  /// step returns `is_new_user: true` and routes the UI to the registration
  /// screen. Anything else logs in directly.
  bool _isNewUserPhone(String phoneE164) => phoneE164.endsWith('9');

  @override
  Future<OtpRequestInfo> sendOtp({
    required String phoneE164,
    String? deviceToken,
    String? platform,
    String? locale,
  }) async {
    await Future.delayed(mockNetworkDelay);
    return OtpRequestInfo(
      isNewUser: _isNewUserPhone(phoneE164),
      expiresIn: AppConstants.otpExpirySecondsFallback,
      cooldownSeconds: AppConstants.otpResendCooldownFallback,
      delivery: 'mock',
      hint: 'استخدم الرمز 123456 للاختبار',
    );
  }

  @override
  Future<VerifyOtpResult> verifyOtp({
    required String phoneE164,
    required String code,
    DeviceMetadata? device,
  }) async {
    // `device` is intentionally accepted but unused — the mock has no FCM /
    // backend to register against, so we just satisfy the [AuthRepository]
    // contract.
    final _ = device;
    await Future.delayed(mockNetworkDelay);

    if (code != mockOtp) {
      throw const UnauthorizedException(
        message: 'الرمز غير صحيح',
        code: 'INVALID_OTP',
      );
    }

    if (_isNewUserPhone(phoneE164)) {
      return VerifyOtpNeedsRegistration(phoneE164: phoneE164, code: code);
    }

    final session = AuthSession(
      accessToken: 'mock.access.${DateTime.now().millisecondsSinceEpoch}',
      user: UserModel(
        id: 'mock-user-id',
        phoneE164: phoneE164,
        name: 'مستخدم تجريبي',
        currency: AppConstants.defaultCurrency,
        language: AppConstants.defaultLocale,
      ),
    );
    await local.saveSession(session);
    return VerifyOtpAuthenticated(session);
  }

  @override
  Future<AuthSession> register({
    required String phoneE164,
    required String code,
    required String name,
    required String currency,
    required String language,
    String? email,
    num? monthlyIncome,
    DeviceMetadata? device,
  }) async {
    // See note in [verifyOtp]: `device` is part of the contract but the
    // mock has no backend to forward it to.
    final _ = device;
    await Future.delayed(mockNetworkDelay);

    if (code != mockOtp) {
      throw const UnauthorizedException(
        message: 'الرمز غير صحيح',
        code: 'INVALID_OTP',
      );
    }

    final session = AuthSession(
      accessToken: 'mock.access.${DateTime.now().millisecondsSinceEpoch}',
      user: UserModel(
        id: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
        phoneE164: phoneE164,
        name: name,
        email: email,
        currency: currency,
        language: language,
        monthlyIncome: monthlyIncome,
      ),
    );
    await local.saveSession(session);
    return session;
  }

  @override
  Future<AuthSession?> loadSession() => local.loadSession();

  @override
  Future<UserModel?> refreshCurrentUser() async {
    final session = await local.loadSession();
    return session?.user;
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    num? monthlyIncome,
    String? currency,
    String? language,
  }) async {
    await Future.delayed(mockNetworkDelay);
    final session = await local.loadSession();
    final base = session?.user ??
        const UserModel(id: 'mock-user-id', phoneE164: '');
    final updated = base.copyWith(
      name: name,
      email: email,
      monthlyIncome: monthlyIncome,
      currency: currency,
      language: language,
    );
    await local.updateUser(updated);
    return updated;
  }

  @override
  Future<void> logout() => local.clearSession();
}
