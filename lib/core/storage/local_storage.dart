import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for non-sensitive data
/// (preferences, cached user profile JSON, onboarding flag, …).
///
/// Sensitive material like access/refresh tokens belongs in `SecureStorage`.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  // ─────────── Strings ───────────
  String? readString(String key) => _prefs.getString(key);
  Future<bool> writeString(String key, String value) =>
      _prefs.setString(key, value);

  // ─────────── Bool ───────────
  bool? readBool(String key) => _prefs.getBool(key);
  Future<bool> writeBool(String key, bool value) =>
      _prefs.setBool(key, value);

  // ─────────── Int ───────────
  int? readInt(String key) => _prefs.getInt(key);
  Future<bool> writeInt(String key, int value) => _prefs.setInt(key, value);

  // ─────────── JSON helpers ───────────
  /// Reads a JSON-encoded map. Returns `null` on missing/corrupt data.
  Map<String, dynamic>? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> writeJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, json.encode(value));

  // ─────────── Removal ───────────
  Future<bool> remove(String key) => _prefs.remove(key);

  bool containsKey(String key) => _prefs.containsKey(key);

  Future<bool> clear() => _prefs.clear();
}

/// Provides the eagerly-initialised [SharedPreferences] instance. The real
/// instance is injected from `main.dart` via an override so the rest of the
/// app can read it synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() with a value '
    'obtained from SharedPreferences.getInstance().',
  );
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage(ref.watch(sharedPreferencesProvider));
});
