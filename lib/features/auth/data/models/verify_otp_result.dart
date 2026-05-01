import 'auth_session.dart';

/// Outcome of `POST /auth/verify-otp`.
///
/// - Existing user → backend returns a Sanctum token + user → wrapped in
///   [VerifyOtpAuthenticated].
/// - New user → backend returns `{ verified: true, is_new_user: true }`
///   without a token. We hold the verified `phone` + `code` pair in
///   [VerifyOtpNeedsRegistration] so the registration screen can submit
///   them straight to `POST /auth/register`.
sealed class VerifyOtpResult {
  const VerifyOtpResult();
}

class VerifyOtpAuthenticated extends VerifyOtpResult {
  const VerifyOtpAuthenticated(this.session);
  final AuthSession session;
}

class VerifyOtpNeedsRegistration extends VerifyOtpResult {
  const VerifyOtpNeedsRegistration({
    required this.phoneE164,
    required this.code,
  });
  final String phoneE164;
  final String code;
}
