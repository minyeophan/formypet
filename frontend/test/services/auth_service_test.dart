import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/auth_service.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
  });

  test('updateProfile sends PATCH nickname and parses the returned id', () async {
    RequestOptions? captured;
    dio.httpClientAdapter = _CannedAdapter((options) {
      captured = options;
      return _jsonResponse(options, 200, {
        'data': {
          'id': 42,
          'email': 'user@example.com',
          'nickname': 'Renamed',
          'profileImageUrl': null,
          'registrationSource': 'LOCAL',
        },
      });
    });

    final profile = await AuthService().updateProfile(nickname: 'Renamed');

    expect(captured?.method, 'PATCH');
    expect(captured?.path, '/api/v1/users/me');
    expect(captured?.data, {'nickname': 'Renamed'});
    expect(profile.id, '42');
    expect(profile.nickname, 'Renamed');
  });

  test('uploadProfileImage sends a multipart file with its original name', () async {
    FormData? captured;
    dio.httpClientAdapter = _CannedAdapter((options) {
      captured = options.data as FormData;
      return _jsonResponse(options, 201, {
        'data': {
          'id': 42,
          'email': 'user@example.com',
          'nickname': 'Momo',
          'profileImageUrl': '/api/v1/media/12',
          'registrationSource': 'LOCAL',
        },
      });
    });

    final profile = await AuthService().uploadProfileImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'portrait.webp',
    );

    expect(captured?.fields, isEmpty);
    expect(captured?.files.map((entry) => entry.key), ['file']);
    expect(captured?.files.single.value.filename, 'portrait.webp');
    expect(profile.id, '42');
    expect(profile.profileImageUrl, '/api/v1/media/12');
  });
}

ResponseBody _jsonResponse(
  RequestOptions options,
  int statusCode,
  Map<String, dynamic> body,
) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}
