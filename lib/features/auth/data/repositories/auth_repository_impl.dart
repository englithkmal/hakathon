import '../../../../core/errors/exceptions.dart';
import '../data_sources/auth_local_data_source.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../models/auth_session.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// Live, Supabase-backed implementation of [AuthRepository].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  @override
  Future<AuthSession> login({
    required String phoneE164,
    required String password,
  }) async {
    final session = await remote.login(
      LoginBody(phoneE164: phoneE164, password: password),
    );
    await local.saveSession(session);
    return session;
  }

  @override
  Future<AuthSession> register({
    required String phoneE164,
    required String password,
    required String name,
    required String currency,
    required String language,
    String? email,
    num? monthlyIncome,
  }) async {
    final session = await remote.register(
      RegisterBody(
        phoneE164: phoneE164,
        password: password,
        name: name,
        currency: currency,
        language: language,
        email: email,
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
    try {
      final user = await remote.me();
      await local.updateUser(user);
      return user;
    } on UnauthorizedException {
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
