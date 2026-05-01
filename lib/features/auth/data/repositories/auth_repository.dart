import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/devices/device_metadata_resolver.dart';
import '../data_sources/auth_local_data_source.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../models/auth_session.dart';
import '../models/otp_request_info.dart';
import '../models/user_model.dart';
import '../models/verify_otp_result.dart';
import 'auth_repository_impl.dart';
import 'mock_auth_repository.dart';

/// Domain-facing API the presentation layer talks to. Hides remote vs.
/// local-only / mocked implementations.
abstract class AuthRepository {
  /// Sends an OTP and returns the metadata the OTP screen needs:
  /// `is_new_user`, `expires_in`, `cooldown_seconds`, optional `delivery`
  /// channel and human-readable `hint`.
  Future<OtpRequestInfo> sendOtp({
    required String phoneE164,
    String? deviceToken,
    String? platform,
    String? locale,
  });

  /// Verifies the OTP. Returns either an authenticated session or a
  /// [VerifyOtpNeedsRegistration] payload that the caller should forward
  /// to [register] after collecting the user's profile.
  ///
  /// [device] carries the same fields used by `/devices/register-guest`
  /// (FCM token, platform, locale, device meta) so the backend can
  /// auto-link the device to the freshly-authenticated user.
  Future<VerifyOtpResult> verifyOtp({
    required String phoneE164,
    required String code,
    DeviceMetadata? device,
  });

  /// Completes registration for a new user. Must be called with the same
  /// `phone` + `code` returned by [verifyOtp]. [device] mirrors the one
  /// passed to [verifyOtp] so the new account starts with a registered
  /// FCM token immediately.
  Future<AuthSession> register({
    required String phoneE164,
    required String code,
    required String name,
    required String currency,
    required String language,
    String? email,
    num? monthlyIncome,
    DeviceMetadata? device,
  });

  /// Latest cached session (token + user) or `null` if the user is logged out.
  Future<AuthSession?> loadSession();

  /// Re-fetches `me` from the backend and refreshes the cached profile.
  /// Implementations may no-op for the mock repo.
  Future<UserModel?> refreshCurrentUser();

  /// Patches the user's profile (`PUT /auth/profile`). Pass only the
  /// fields the user actually changed; the rest stay untouched on the
  /// backend. The returned [UserModel] is also written to local cache
  /// so the rest of the app sees the new value immediately.
  Future<UserModel> updateProfile({
    String? name,
    String? email,
    num? monthlyIncome,
    String? currency,
    String? language,
  });

  /// Logs out from the backend (best-effort) and clears local session.
  Future<void> logout();
}

/// Selects between the live and mocked repositories.
///
/// While [AppConstants.useMockBackend] is `true`, the app runs entirely
/// off-line with the canned OTP `123456` — perfect for design/QA work
/// before the backend ships.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final local = ref.watch(authLocalDataSourceProvider);

  if (AppConstants.useMockBackend) {
    return MockAuthRepository(local: local);
  }

  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: local,
  );
});
