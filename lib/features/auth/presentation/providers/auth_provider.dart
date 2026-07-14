import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../devices/application/authenticated_device_service.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

/// Sealed hierarchy describing the user's authentication state.
sealed class AuthState {
  const AuthState();
}

/// Transient bootstrap state — the notifier is reading the persisted session
/// from secure storage. The router shows the splash while we're here.
class AuthInitializing extends AuthState {
  const AuthInitializing();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
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
  /// either [AuthAuthenticated] (valid token) or [AuthUnauthenticated].
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

  /// تسجيل الدخول برقم الجوال + كلمة المرور.
  /// يُرجع `null` عند النجاح، أو [Failure] للعرض في الواجهة.
  Future<Failure?> login({
    required String phoneE164,
    required String password,
  }) async {
    try {
      final session = await _repo.login(
        phoneE164: phoneE164,
        password: password,
      );
      state = AuthAuthenticated(
        phoneE164: session.user?.phoneE164 ?? phoneE164,
        accessToken: session.accessToken,
        user: session.user,
      );
      // ربط جهاز الإشعارات بالحساب الجديد (best-effort).
      _registerDeviceSafely();
      return null;
    } on AppException catch (e) {
      return e.toFailure();
    }
  }

  /// إنشاء حساب جديد ثم تسجيل الدخول مباشرة.
  Future<Failure?> register({
    required String phoneE164,
    required String password,
    required String name,
    required String currency,
    required String language,
    String? email,
    num? monthlyIncome,
  }) async {
    try {
      final session = await _repo.register(
        phoneE164: phoneE164,
        password: password,
        name: name,
        currency: currency,
        language: language,
        email: email,
        monthlyIncome: monthlyIncome,
      );
      state = AuthAuthenticated(
        phoneE164: session.user?.phoneE164 ?? phoneE164,
        accessToken: session.accessToken,
        user: session.user,
      );
      _registerDeviceSafely();
      return null;
    } on AppException catch (e) {
      return e.toFailure();
    }
  }

  /// Patches the authenticated user's profile and updates the
  /// in-memory [AuthAuthenticated] state with the new [UserModel].
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
      state = AuthAuthenticated(
        phoneE164: updated.phoneE164.isNotEmpty
            ? updated.phoneE164
            : current.phoneE164,
        accessToken: current.accessToken,
        user: updated,
      );
      ref.invalidate(dashboardProvider);
      return null;
    } on AppException catch (e) {
      return e.toFailure();
    }
  }

  Future<void> logout() async {
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

  /// Best-effort: ربط رمز FCM بالحساب الجديد بعد تسجيل الدخول/التسجيل.
  void _registerDeviceSafely() {
    final current = state;
    if (current is! AuthAuthenticated) return;
    final userId = current.user?.id ?? '';
    if (userId.isEmpty) return;
    Future(() async {
      try {
        await ref.read(authenticatedDeviceServiceProvider).onAuthenticated(userId);
      } catch (e, st) {
        debugPrint('AuthNotifier: device register failed: $e\n$st');
      }
    });
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
