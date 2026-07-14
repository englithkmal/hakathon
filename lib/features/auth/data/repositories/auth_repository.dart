import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../data_sources/auth_local_data_source.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../models/auth_session.dart';
import '../models/user_model.dart';
import 'auth_repository_impl.dart';
import 'mock_auth_repository.dart';

/// Domain-facing API the presentation layer talks to. Hides remote vs.
/// local-only / mocked implementations.
abstract class AuthRepository {
  /// تسجيل الدخول برقم الجوال + كلمة المرور.
  Future<AuthSession> login({
    required String phoneE164,
    required String password,
  });

  /// إنشاء حساب جديد برقم الجوال + كلمة المرور + الملف الشخصي.
  Future<AuthSession> register({
    required String phoneE164,
    required String password,
    required String name,
    required String currency,
    required String language,
    String? email,
    num? monthlyIncome,
  });

  /// Latest cached session (token + user) or `null` if the user is logged out.
  Future<AuthSession?> loadSession();

  /// Re-fetches `me` from the backend and refreshes the cached profile.
  Future<UserModel?> refreshCurrentUser();

  /// Patches the user's profile. Pass only the fields the user actually
  /// changed.
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
