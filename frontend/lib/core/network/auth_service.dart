import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service tunggal untuk menyimpan dan membaca Bearer Token
/// dari Keystore (Android) / Keychain (iOS) secara aman.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'sanctum_token';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserId = 'user_id';

  // ── Token ──────────────────────────────────────────────
  Future<void> saveToken(String token) => _storage.write(key: _keyToken, value: token);
  Future<String?> getToken() => _storage.read(key: _keyToken);
  Future<bool> hasToken() async => (await getToken()) != null;

  // ── User Info ──────────────────────────────────────────
  Future<void> saveUser({
    required int id,
    required String name,
    required String email,
  }) async {
    await _storage.write(key: _keyUserId,    value: id.toString());
    await _storage.write(key: _keyUserName,  value: name);
    await _storage.write(key: _keyUserEmail, value: email);
  }

  Future<Map<String, String?>> getUser() async {
    return {
      'id':    await _storage.read(key: _keyUserId),
      'name':  await _storage.read(key: _keyUserName),
      'email': await _storage.read(key: _keyUserEmail),
    };
  }

  // ── Logout ─────────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();
}
