import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/user_profile.dart';
import 'kakao_bootstrap.dart';
import 'account_deletion_cleanup.dart';

class KakaoSignupInterrupted implements Exception {
  final String message;
  KakaoSignupInterrupted(this.message);
}

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
    if (!await AccountDeletionCleanup.instance.retryPending()) {
      throw StateError('이전 계정의 기기 내 데이터 정리를 완료하지 못했어요.');
    }
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
    Map<String, dynamic>? policyAcceptance,
  }) async {
    final session = ++_session;
    final res = await dio.post(
      '/api/v1/auth/register',
      data: {
        'email': email,
        'password': password,
        'nickname': nickname,
        if (policyAcceptance != null && policyAcceptance.isNotEmpty)
          'policyAcceptance': policyAcceptance,
      },
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

  Future<UserProfile?> loginWithKakao({
    Future<Map<String, dynamic>?> Function()? requestConsent,
  }) async {
    final session = ++_session;
    final token = await _loginWithKakaoSdk();
    _requireSession(session);
    if (token == null) {
      return null;
    }

    var res = await dio.post(
      '/api/v1/auth/kakao',
      options: Options(headers: {'X-Policy-Flow': '1'}),
      data: {'accessToken': token.accessToken},
    );
    final pending = unwrap(res) as Map<String, dynamic>;
    if (pending['signupRequired'] == true) {
      final signupToken = pending['signupToken'] as String;
      try {
        final acceptance = await requestConsent?.call();
        _requireSession(session);
        if (acceptance == null || acceptance.isEmpty) {
          final cancelled =
              unwrap(
                    await dio.post(
                      '/api/v1/auth/kakao/signup-cancellation',
                      data: {'signupToken': signupToken},
                    ),
                  )
                  as Map;
          throw KakaoSignupInterrupted(
            cancelled['status'] == 'CANCELLED'
                ? '포마펫 계정은 만들지 않았어요. 카카오 연결 해제는 처리 중이며 지연될 수 있어요.'
                : '가입 진행을 중단했어요. 계정 또는 카카오 연결 상태는 다시 로그인하여 확인해 주세요.',
          );
        }
        res = await dio.post(
          '/api/v1/auth/kakao',
          data: {
            'accessToken': token.accessToken,
            'signupToken': signupToken,
            'policyAcceptance': acceptance,
          },
          options: Options(headers: {'X-Policy-Flow': '1'}),
        );
      } on KakaoSignupInterrupted {
        rethrow;
      } catch (_) {
        // The server also expires abandoned intents, including process termination.
        // Cancellation checks for an existing service account before queuing unlink.
        try {
          await dio.post(
            '/api/v1/auth/kakao/signup-cancellation',
            data: {'signupToken': signupToken},
          );
        } catch (_) {}
        rethrow;
      }
    }
    return _acceptTokens(res, session);
  }

  Future<bool> deleteAccount({String? password}) async {
    final session = ++_session;
    final credentials = <String, String>{};
    if (password != null) {
      credentials['password'] = password;
    } else {
      final token = await _loginWithKakaoSdk();
      _requireSession(session);
      if (token == null) return false;
      credentials['kakaoAccessToken'] = token.accessToken;
    }
    final response = await dio.delete('/api/v1/users/me', data: credentials);
    _requireSession(session);
    final result = unwrap(response) as Map<String, dynamic>;
    if (result['status'] != 'ACCEPTED') {
      throw StateError('Account deletion was not accepted');
    }
    return true;
  }

  Future<OAuthToken?> _loginWithKakaoSdk() async {
    await KakaoBootstrap.ensureReady();
    final kakaoTalkAvailable = await isKakaoTalkInstalled();
    if (kakaoTalkAvailable) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } on KakaoClientException catch (e) {
        if (_isUserCancelled(e)) {
          return null;
        }
      } catch (e) {
        final accountNotConnected = e is PlatformException &&
            e.code == 'NotSupportError' &&
            (e.message?.toLowerCase().contains(
                  'not connected to kakao account',
                ) ??
                false);
        if (!accountNotConnected) rethrow;
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
