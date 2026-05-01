import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/devices/device_metadata_resolver.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../devices/application/authenticated_device_service.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/models/verify_otp_result.dart';
import '../../data/repositories/auth_repository.dart';

/// Sealed hierarchy describing the user's authentication state.
sealed class AuthState {
  const AuthState();
}

/// Transient bootstrap state — the notifier is reading the persisted session
/// from secure storage. The router shows the splash while we're here so the
/// user never sees a brief flash of `/login` before being sent to `/home`.
class AuthInitializing extends AuthState {
  const AuthInitializing();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAwaitingOtp extends AuthState {
  const AuthAwaitingOtp({
    required this.phoneE164,
    required this.displayPhone,
    required this.expiresIn,
    required this.cooldownSeconds,
    this.delivery,
    this.hint,
  });

  /// E.164 formatted phone (e.g. `+9665XXXXXXXX`).
  final String phoneE164;

  /// Pretty form intended for the UI (e.g. `+966 5X XXX XXXX`).
  final String displayPhone;

  /// Seconds until the issued OTP expires server-side.
  final int expiresIn;

  /// Seconds the user must wait before another `send-otp` is allowed.
  final int cooldownSeconds;

  /// `push` | `sms` | etc.
  final String? delivery;

  /// Localised hint from the backend (e.g. "تم إرساله كإشعار...").
  final String? hint;
}

/// The OTP was verified for a phone we've never seen — the UI must collect
/// profile info and call [AuthNotifier.register] to finish onboarding.
class AuthRegistrationRequired extends AuthState {
  const AuthRegistrationRequired({
    required this.phoneE164,
    required this.displayPhone,
    required this.code,
  });

  final String phoneE164;
  final String displayPhone;
  final String code;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.phoneE164,
    this.accessToken,
    this.user,
  });

  final String phoneE164;
  final String? accessToken;
  final UserModel? user;
}

/// Riverpod notifier that drives the auth UI. All actual networking + caching
/// happens inside [AuthRepository], which is swapped between mock and real
/// implementations via `AppConstants.useMockBackend`.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;

  @override
  AuthState build() {
    _repo = ref.watch(authRepositoryProvider);
    _restore();
    return const AuthInitializing();
  }

  /// Reads any persisted session from storage. Always resolves the state to
  /// either [AuthAuthenticated] (valid token) or [AuthUnauthenticated] (no
  /// token / expired) — the router relies on us *eventually* leaving the
  /// initializing state so the splash can dismiss.
  Future<void> _restore() async {
    try {
      final session = await _repo.loadSession();
      if (session == null || session.accessToken.isEmpty) {
        state = const AuthUnauthenticated();
        return;
      }

      if (session.isExpired && session.refreshToken == null) {
        await _repo.logout();
        state = const AuthUnauthenticated();
        return;
      }

      state = AuthAuthenticated(
        phoneE164: session.user?.phoneE164 ?? '',
        accessToken: session.accessToken,
        user: session.user,
      );
    } catch (e, st) {
      debugPrint('AuthNotifier._restore failed: $e\n$st');
      state = const AuthUnauthenticated();
    }
  }

  /// Sends an OTP and transitions into [AuthAwaitingOtp].
  ///
  /// Returns `null` on success, or a [Failure] describing the issue so the
  /// UI can show a localised error.
  Future<Failure?> requestOtp({
    required String phoneE164,
    required String displayPhone,
    String? deviceToken,
    String? locale,
  }) async {
    try {
      final info = await _repo.sendOtp(
        phoneE164: phoneE164,
        deviceToken: deviceToken,
        platform: _currentPlatform(),
        locale: locale,
      );
      state = AuthAwaitingOtp(
        phoneE164: phoneE164,
        displayPhone: displayPhone,
        expiresIn: info.expiresIn,
        cooldownSeconds: info.cooldownSeconds,
        delivery: info.delivery,
        hint: info.hint,
      );
      return null;
    } on AppException catch (e) {
      return e.toFailure();
    }
  }

  /// Verifies the OTP. On success transitions to [AuthAuthenticated] for
  /// existing users, or [AuthRegistrationRequired] for new users.
  /// Returns `null` on success, otherwise a [Failure].
  Future<Failure?> verifyOtp(String code) async {
    final current = state;
    if (current is! AuthAwaitingOtp) {
      return const UnknownFailure(message: 'No pending OTP request');
    }

    try {
      // Gather device meta (FCM token + platform + locale + device info)
      // so the backend can link this device to the freshly-authenticated
      // user account on the same request. Without this, only OTP pushes
      // and guest broadcasts reach the device — every per-user push stays
      // silent until the next manual `/devices/register` call.
      final device = await _resolveDeviceMetadata();
      final result = await _repo.verifyOtp(
        phoneE164: current.phoneE164,
        code: code,
        device: device,
      );
      switch (result) {
        case VerifyOtpAuthenticated(:final session):
          state = AuthAuthenticated(
            phoneE164: session.user?.phoneE164 ?? current.phoneE164,
            accessToken: session.accessToken,
            user: session.user,
          );
        case VerifyOtpNeedsRegistration(:final phoneE164, :final code):
          state = AuthRegistrationRequired(
            phoneE164: phoneE164,
            displayPhone: current.displayPhone,
            code: code,
          );
      }
      return null;
    } on AppException catch (e) {
      return e.toFailure();
    }
  }

  /// Re-issues the OTP — same backend call as [requestOtp] (Waffer doesn't
  /// expose a separate `resend` endpoint, the cooldown is enforced server-side).
  Future<Failure?> resendOtp() async {
    final current = state;
    if (current is! AuthAwaitingOtp) {
      return const UnknownFailure(message: 'No pending OTP request');
    }
    try {
      final info = await _repo.sendOtp(
        phoneE164: current.phoneE164,
        platform: _currentPlatform(),
      );
      state = AuthAwaitingOtp(
        phoneE164: current.phoneE164,
        displayPhone: current.displayPhone,
        expiresIn: info.expiresIn,
        cooldownSeconds: info.cooldownSeconds,
        delivery: info.delivery,
        hint: info.hint,
      );
      return null;
    } on AppException catch (e) {
      return e.toFailure();
    }
  }

  /// Completes registration for a new user. The notifier holds the verified
  /// `phone` + `code` pair — the UI only collects profile info and calls this.
  Future<Failure?> register({
    required String name,
    required String currency,
    required String language,
    String? email,
    num? monthlyIncome,
  }) async {
    final current = state;
    if (current is! AuthRegistrationRequired) {
      return const UnknownFailure(message: 'No pending registration');
    }
    try {
      // Same rationale as `verifyOtp`: forward device meta so the new
      // account is linked to this device's FCM token from the very first
      // authenticated request.
      final device = await _resolveDeviceMetadata();
      final session = await _repo.register(
        phoneE164: current.phoneE164,
        code: current.code,
        name: name,
        currency: currency,
        language: language,
        email: email,
        monthlyIncome: monthlyIncome,
        device: device,
      );
      state = AuthAuthenticated(
        phoneE164: session.user?.phoneE164 ?? current.phoneE164,
        accessToken: session.accessToken,
        user: session.user,
      );
      return null;
    } on AppException catch (e) {
      return e.toFailure();
    }
  }

  /// Patches the authenticated user's profile and updates the
  /// in-memory [AuthAuthenticated] state with the new [UserModel].
  /// Returns `null` on success, otherwise a [Failure] for the UI to
  /// display.
  Future<Failure?> updateProfile({
    String? name,
    String? email,
    num? monthlyIncome,
    String? currency,
    String? language,
  }) async {
    final current = state;
    if (current is! AuthAuthenticated) {
      return const UnknownFailure(message: 'Not authenticated');
    }
    try {
      final updated = await _repo.updateProfile(
        name: name,
        email: email,
        monthlyIncome: monthlyIncome,
        currency: currency,
        language: language,
      );
      // Re-issue the authenticated state with the new user record so
      // every screen watching `authProvider` (e.g. the currency
      // provider fallback, the home greeting) reacts immediately.
      state = AuthAuthenticated(
        phoneE164: updated.phoneE164.isNotEmpty
            ? updated.phoneE164
            : current.phoneE164,
        accessToken: current.accessToken,
        user: updated,
      );
      // The dashboard endpoint echoes the user's currency back as
      // `dashboard.currency`; invalidate it so the next read refetches
      // with the server-authoritative value rather than serving the
      // pre-update cache.
      ref.invalidate(dashboardProvider);
      return null;
    } on AppException catch (e) {
      return e.toFailure();
    }
  }

  /// Goes back to phone entry, dropping any pending OTP / registration.
  void editPhone() {
    state = const AuthUnauthenticated();
  }

  Future<void> logout() async {
    // Unregister the device while we still have a valid Bearer token —
    // otherwise the backend will keep pushing user-targeted notifications to
    // an FCM token nobody owns. Best-effort: never blocks logout.
    try {
      await ref.read(authenticatedDeviceServiceProvider).onLoggedOut();
    } catch (e, st) {
      debugPrint('AuthNotifier.logout: device unregister failed: $e\n$st');
    }
    try {
      await _repo.logout();
    } catch (e, st) {
      debugPrint('AuthNotifier.logout failed: $e\n$st');
    } finally {
      state = const AuthUnauthenticated();
    }
  }

  static String _currentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

  /// Best-effort device metadata for `verify-otp` / `register`. Falls back
  /// to a minimal payload (just `platform`) if the resolver throws — we
  /// never want a flaky `device_info_plus` / FCM call to block login.
  Future<DeviceMetadata?> _resolveDeviceMetadata() async {
    try {
      return await ref.read(deviceMetadataResolverProvider).resolve();
    } catch (e, st) {
      debugPrint('AuthNotifier: device metadata resolve failed: $e\n$st');
      return DeviceMetadata(platform: _currentPlatform());
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
