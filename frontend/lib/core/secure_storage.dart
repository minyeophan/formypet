import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _accessKey = 'access_token';
const _refreshKey = 'refresh_token';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

Future<void> _credentialWrites = Future.value();
// Advance on login/logout intent, so a queued refresh cannot overwrite it.
int _credentialRevision = 0;
int get credentialRevision => _credentialRevision;

Future<T> _serial<T>(Future<T> Function() operation) {
  final pending = _credentialWrites.then((_) => operation());
  _credentialWrites = pending.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  return pending;
}

Future<String?> getAccessToken() =>
    _serial(() => _storage.read(key: _accessKey));
Future<String?> getRefreshToken() =>
    _serial(() => _storage.read(key: _refreshKey));

Future<({String? access, String? refresh, int revision})> readCredentials() =>
    _serial(() async {
      final revision = _credentialRevision;
      return (
        access: await _storage.read(key: _accessKey),
        refresh: await _storage.read(key: _refreshKey),
        revision: revision,
      );
    });

Future<void> _writeTokens(String access, String refresh) async {
  await _storage.write(key: _accessKey, value: access);
  await _storage.write(key: _refreshKey, value: refresh);
}

Future<void> saveTokens({required String access, required String refresh}) {
  _credentialRevision++;
  return _serial(() => _writeTokens(access, refresh));
}

Future<void> saveAccessToken(String access) {
  _credentialRevision++;
  return _serial(() => _storage.write(key: _accessKey, value: access));
}

Future<int?> replaceTokensIfCurrent({
  required int expectedRevision,
  required String access,
  required String refresh,
}) => _serial(() async {
  if (_credentialRevision != expectedRevision) return null;
  final revision = ++_credentialRevision;
  await _writeTokens(access, refresh);
  return revision;
});

Future<void> _deleteTokens() async {
  await _storage.delete(key: _accessKey);
  await _storage.delete(key: _refreshKey);
}

Future<void> clearTokens() {
  _credentialRevision++;
  return _serial(_deleteTokens);
}

Future<int?> clearTokensIfCurrent(int expectedRevision) => _serial(() async {
  if (_credentialRevision != expectedRevision) return null;
  final revision = ++_credentialRevision;
  await _deleteTokens();
  return revision;
});
