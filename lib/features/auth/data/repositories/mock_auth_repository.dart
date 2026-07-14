import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../data_sources/auth_local_data_source.dart';
import '../models/auth_session.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// In-memory implementation for QA/design work without a backend.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({required this.local});

  static const Duration mockNetworkDelay = Duration(milliseconds: 500);

  final AuthLocalDataSource local;

  @override
  Future<AuthSession> login({
    required String phoneE164,
    required String password,
  }) async {
    await Future.delayed(mockNetworkDelay);
    if (password.length < 6) {
      throw const UnauthorizedException(
        message: 'رقم الجوال أو كلمة المرور غير صحيحة.',
        statusCode: 401,
      );
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
    await Future.delayed(mockNetworkDelay);
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
