import '../../../../core/devices/device_metadata_resolver.dart';
import '../../../../core/errors/exceptions.dart';
import '../data_sources/auth_local_data_source.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../models/auth_session.dart';
import '../models/login_request.dart';
import '../models/otp_request_info.dart';
import '../models/register_request.dart';
import '../models/user_model.dart';
import '../models/verify_otp_result.dart';
import 'auth_repository.dart';

/// Live, network-backed implementation of [AuthRepository].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  @override
  Future<OtpRequestInfo> sendOtp({
    required String phoneE164,
    String? deviceToken,
    String? platform,
    String? locale,
  }) {
    return remote.sendOtp(
      RequestOtpBody(
        phoneE164: phoneE164,
        deviceToken: deviceToken,
        platform: platform,
        locale: locale,
      ),
    );
  }

  @override
  Future<VerifyOtpResult> verifyOtp({
    required String phoneE164,
    required String code,
    DeviceMetadata? device,
  }) async {
    final result = await remote.verifyOtp(
      VerifyOtpBody(
        phoneE164: phoneE164,
        code: code,
        deviceToken: device?.token,
        platform: device?.platform,
        locale: device?.locale,
        deviceName: device?.deviceName,
        deviceModel: device?.deviceModel,
        appVersion: device?.appVersion,
      ),
    );
    if (result is VerifyOtpAuthenticated) {
      // Backend may not echo back the phone in the user payload; ensure
      // we always cache something usable.
      final session = result.session;
      final enriched = (session.user == null)
          ? session.copyWith(
              user: UserModel(id: '', phoneE164: phoneE164),
            )
          : session;
      await local.saveSession(enriched);
      return VerifyOtpAuthenticated(enriched);
    }
    return result;
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
    final session = await remote.register(
      RegisterBody(
        phoneE164: phoneE164,
        code: code,
        name: name,
        currency: currency,
        language: language,
        email: email,
        monthlyIncome: monthlyIncome,
        deviceToken: device?.token,
        platform: device?.platform,
        locale: device?.locale,
        deviceName: device?.deviceName,
        deviceModel: device?.deviceModel,
        appVersion: device?.appVersion,
      ),
    );
    final enriched = (session.user == null)
        ? session.copyWith(
            user: UserModel(
              id: '',
              phoneE164: phoneE164,
              name: name,
              email: email,
              currency: currency,
              language: language,
              monthlyIncome: monthlyIncome,
            ),
          )
        : session;
    await local.saveSession(enriched);
    return enriched;
  }

  @override
  Future<AuthSession?> loadSession() => local.loadSession();

  @override
  Future<UserModel?> refreshCurrentUser() async {
    try {
      final user = await remote.me();
      await local.updateUser(user);
      return user;
    } on UnauthorizedException {
      // Token expired / revoked → drop session so router pushes /login.
      await local.clearSession();
      return null;
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
    final updated = await remote.updateProfile(
      name: name,
      email: email,
      monthlyIncome: monthlyIncome,
      currency: currency,
      language: language,
    );
    // Persist locally so the cached session reflects the change even
    // before the next app restart.
    await local.updateUser(updated);
    return updated;
  }

  @override
  Future<void> logout() async {
    try {
      await remote.logout();
    } catch (_) {
      // Best-effort: even if the backend fails, the local session must die.
    }
    await local.clearSession();
  }
}
