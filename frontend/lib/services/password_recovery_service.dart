import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class RecoveryChallenge {
  const RecoveryChallenge(this.id, this.expiresAt, this.resendAvailableAt);
  final String id;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
}

class RecoveryVerified {
  const RecoveryVerified(this.token, this.expiresAt);
  final String token;
  final DateTime expiresAt;
}

String recoveryRequestId() => base64UrlEncode(
  List<int>.generate(24, (_) => Random.secure().nextInt(256)),
).replaceAll('=', '');

class PasswordRecoveryService {
  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, String> data,
  ) async {
    final response = await dio.post(
      '/api/v1/auth/password-reset/$action',
      data: data,
      options: Options(extra: {'_skipAuth': true, '_noTransientRetry': true}),
    );
    if (response.statusCode != 200) {
      throw const FormatException('Unexpected recovery response');
    }
    if (action == 'confirm') return const {};
    final result = unwrap(response);
    if (result is! Map<String, dynamic>) {
      throw const FormatException('Invalid recovery response');
    }
    return result;
  }

  Future<RecoveryChallenge> request(String email) async {
    final data = await _post('request', {'email': email.trim()});
    return RecoveryChallenge(
      data['challengeId'] as String,
      DateTime.parse(data['expiresAt'] as String),
      DateTime.parse(data['resendAvailableAt'] as String),
    );
  }

  Future<RecoveryVerified> verify(
    String challengeId,
    String code,
    String requestId,
  ) async {
    final data = await _post('verify', {
      'challengeId': challengeId,
      'code': code,
      'requestId': requestId,
    });
    return RecoveryVerified(
      data['resetToken'] as String,
      DateTime.parse(data['expiresAt'] as String),
    );
  }

  Future<void> confirm(String token, String password, String requestId) async {
    await _post('confirm', {
      'resetToken': token,
      'newPassword': password,
      'requestId': requestId,
    });
  }
}

String recoveryErrorMessage(Object error) {
  final status = error is DioException ? error.response?.statusCode : null;
  return switch (status) {
    400 => '인증 정보가 올바르지 않거나 만료됐어요. 입력 내용을 확인하거나 다시 요청해 주세요.',
    409 => '이미 처리되었거나 변경된 요청이에요. 새 비밀번호로 로그인해 보거나 복구를 다시 시작해 주세요.',
    429 => '요청이 많아요. 잠시 후 다시 시도해 주세요.',
    503 => '현재 비밀번호 복구를 이용할 수 없어요. 잠시 후 다시 시도해 주세요.',
    _ => '처리 결과를 확인하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.',
  };
}
