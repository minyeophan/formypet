import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';

class AuthService {
  int _session = 0;
  Future<void> _credentialWrite = Future.value();

  void invalidatePendingAuthentication() => _session++;

  void _requireSession(int session) {
    if (session != _session) throw StateError('Authentication session changed');
  }

  Future<void> _writeCredentials(Future<void> Function() write) {
    final pending = _credentialWrite.then((_) => write());
    _credentialWrite = pending.catchError((_) {});
    return pending;
  }

  Future<UserProfile> _acceptTokens(Response res, int session) async {
    _requireSession(session);
    final data = unwrap(res) as Map<String, dynamic>;
    await _writeCredentials(() async {
      _requireSession(session);
      await saveTokens(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
    });
    _requireSession(session);
    final profile = await getProfile();
    _requireSession(session);
    return profile;
  }
  // TokenResponse only has {accessToken, refreshToken} — no user field.
  // Must call GET /api/v1/users/me separately after login/register.

  Future<UserProfile> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final session = ++_session;
    final res = await dio.post(
      '/api/v1/auth/register',
      data: {'email': email, 'password': password, 'nickname': nickname},
    );
    return _acceptTokens(res, session);
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final session = ++_session;
    final res = await dio.post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return _acceptTokens(res, session);
  }

  Future<UserProfile?> loginWithKakao() async {
    final session = ++_session;
    final token = await _loginWithKakaoSdk();
    _requireSession(session);
    if (token == null) {
      return null;
    }

    final res = await dio.post(
      '/api/v1/auth/kakao',
      data: {'accessToken': token.accessToken},
    );
    return _acceptTokens(res, session);
  }

  Future<OAuthToken?> _loginWithKakaoSdk() async {
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } on KakaoClientException catch (e) {
        if (_isUserCancelled(e)) {
          return null;
        }
      }
    }

    try {
      return await UserApi.instance.loginWithKakaoAccount();
    } on KakaoClientException catch (e) {
      if (_isUserCancelled(e)) {
        return null;
      }
      rethrow;
    }
  }

  bool _isUserCancelled(KakaoClientException exception) {
    return exception.reason == ClientErrorCause.cancelled;
  }

  Future<void> logout() async {
    final session = ++_session;
    try {
      final refresh = await getRefreshToken();
      if (refresh != null) {
        await dio.post('/api/v1/auth/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {
      // best-effort
    }
    await _writeCredentials(() async {
      if (session == _session) await clearTokens();
    });
  }

  Future<UserProfile> getProfile() async {
    final res = await dio.get('/api/v1/users/me');
    return UserProfile.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile({required String nickname}) async {
    final res = await dio.patch(
      '/api/v1/users/me',
      data: {'nickname': nickname},
    );
    return UserProfile.fromJson(unwrap(res) as Map<String, dynamic>);
  }

  Future<UserProfile> uploadProfileImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final res = await dio.post(
      '/api/v1/users/me/profile-image',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return UserProfile.fromJson(unwrap(res) as Map<String, dynamic>);
  }
}
