import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';

class AuthService {
  // TokenResponse only has {accessToken, refreshToken} — no user field.
  // Must call GET /api/v1/users/me separately after login/register.

  Future<UserProfile> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final res = await dio.post(
      '/api/v1/auth/register',
      data: {'email': email, 'password': password, 'nickname': nickname},
    );
    final data = unwrap(res) as Map<String, dynamic>;
    await saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return getProfile();
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final res = await dio.post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = unwrap(res) as Map<String, dynamic>;
    await saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return getProfile();
  }

  Future<UserProfile?> loginWithKakao() async {
    final token = await _loginWithKakaoSdk();
    if (token == null) {
      return null;
    }

    final res = await dio.post(
      '/api/v1/auth/kakao',
      data: {'accessToken': token.accessToken},
    );
    final data = unwrap(res) as Map<String, dynamic>;
    await saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return getProfile();
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
    try {
      final refresh = await getRefreshToken();
      if (refresh != null) {
        await dio.post('/api/v1/auth/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {
      // best-effort
    }
    await clearTokens();
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
