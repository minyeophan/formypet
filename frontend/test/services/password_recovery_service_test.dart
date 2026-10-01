import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/password_recovery_service.dart';

void main() {
  test('recovery sends no credentials and preserves retry identifiers', () async {
    initApiClient('http://example.test');
    final requests = <RequestOptions>[];
    dio.httpClientAdapter = RecoveryAdapter((request) {
      requests.add(request);
      expect(request.headers.containsKey('Authorization'), isFalse);
      if (request.path.endsWith('/request')) {
        return '{"data":{"challengeId":"challenge","expiresAt":"2026-09-22T08:10:00Z","resendAvailableAt":"2026-09-22T08:01:00Z"}}';
      }
      if (request.path.endsWith('/verify')) {
        return '{"data":{"resetToken":"token","expiresAt":"2026-09-22T08:05:00Z"}}';
      }
      return '{"data":null,"message":"success"}';
    });
    final service = PasswordRecoveryService();
    final challenge = await service.request(' user@example.com ');
    expect(challenge.id, 'challenge');
    final verified = await service.verify(
      challenge.id,
      '012345',
      'verification-operation',
    );
    await service.verify(challenge.id, '012345', 'verification-operation');
    await service.confirm(
      verified.token,
      'NewPassword123!',
      'confirmation-operation',
    );
    expect(requests.first.data, {'email': 'user@example.com'});
    expect(requests[1].data, requests[2].data);
    expect(requests.last.data, {
      'resetToken': 'token',
      'newPassword': 'NewPassword123!',
      'requestId': 'confirmation-operation',
    });
  });
}

class RecoveryAdapter implements HttpClientAdapter {
  RecoveryAdapter(this.handler);
  final String Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      handler(options),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
