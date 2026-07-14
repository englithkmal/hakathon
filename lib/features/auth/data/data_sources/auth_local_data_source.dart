import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../models/auth_session.dart';
import '../models/user_model.dart';

/// Reads / writes the persisted auth session.
///
/// Token material lives in `SecureStorage` (Keychain / EncryptedSharedPrefs);
/// the cached user profile + expiry timestamp live in `LocalStorage`.
abstract class AuthLocalDataSource {
  Future<void> saveSession(AuthSession session);
  Future<AuthSession?> loadSession();
  Future<void> updateUser(UserModel user);
  Future<void> clearSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({
    required SecureStorage secureStorage,
    required LocalStorage localStorage,
  })  : _secure = secureStorage,
        _local = localStorage;

  final SecureStorage _secure;
  final LocalStorage _local;

  @override
  Future<void> saveSession(AuthSession session) async {
    try {
      await _secure.write(StorageKeys.authToken, session.accessToken);

      if (session.refreshToken != null) {
        await _secure.write(
          StorageKeys.refreshToken,
          session.refreshToken!,
        );
      } else {
        await _secure.delete(StorageKeys.refreshToken);
      }

      if (session.expiresAt != null) {
        await _local.writeString(
          StorageKeys.tokenExpiresAt,
          session.expiresAt!.toIso8601String(),
        );
      } else {
        await _local.remove(StorageKeys.tokenExpiresAt);
      }

      if (session.user != null) {
        await _local.writeJson(
          StorageKeys.userJson,
          session.user!.toJson(),
        );
        await _local.writeString(
          StorageKeys.userPhone,
          session.user!.phoneE164,
        );
      }
    } catch (e) {
      throw CacheException(message: 'Failed to save auth session: $e');
    }
  }

  @override
  Future<AuthSession?> loadSession() async {
    try {
      final token = await _secure.read(StorageKeys.authToken);
      if (token == null || token.isEmpty) return null;

      final refresh = await _secure.read(StorageKeys.refreshToken);

      final userMap = _local.readJson(StorageKeys.userJson);
      final user = userMap != null ? UserModel.fromJson(userMap) : null;

      DateTime? expiresAt;
      final expRaw = _local.readString(StorageKeys.tokenExpiresAt);
      if (expRaw != null) {
        expiresAt = DateTime.tryParse(expRaw);
      }

      return AuthSession(
        accessToken: token,
        refreshToken: refresh,
        expiresAt: expiresAt,
        user: user,
      );
    } catch (e) {
      throw CacheException(message: 'Failed to load auth session: $e');
    }
  }

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      await _local.writeJson(StorageKeys.userJson, user.toJson());
      await _local.writeString(StorageKeys.userPhone, user.phoneE164);
    } catch (e) {
      throw CacheException(message: 'Failed to update cached user: $e');
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await _secure.delete(StorageKeys.authToken);
      await _secure.delete(StorageKeys.refreshToken);
      await _local.remove(StorageKeys.userJson);
      await _local.remove(StorageKeys.userPhone);
      await _local.remove(StorageKeys.tokenExpiresAt);
    } catch (e) {
      throw CacheException(message: 'Failed to clear auth session: $e');
    }
  }
}

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(
    secureStorage: ref.watch(secureStorageProvider),
    localStorage: ref.watch(localStorageProvider),
  );
});
