import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around [FlutterSecureStorage] used to keep tokens / sensitive
/// values out of plaintext SharedPreferences.
///
/// Backed by Keychain on iOS and EncryptedSharedPreferences on Android.
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clear() => _storage.deleteAll();

  Future<bool> contains(String key) => _storage.containsKey(key: key);
}

const _androidOptions = AndroidOptions(encryptedSharedPreferences: true);
const _iosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(
    const FlutterSecureStorage(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    ),
  );
});
