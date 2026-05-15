import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _accessKey = 'access_token';
const _refreshKey = 'refresh_token';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

Future<String?> getAccessToken() => _storage.read(key: _accessKey);
Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

Future<void> saveTokens({required String access, required String refresh}) async {
  await _storage.write(key: _accessKey, value: access);
  await _storage.write(key: _refreshKey, value: refresh);
}

Future<void> saveAccessToken(String access) =>
    _storage.write(key: _accessKey, value: access);

Future<void> clearTokens() async {
  await _storage.delete(key: _accessKey);
  await _storage.delete(key: _refreshKey);
}
