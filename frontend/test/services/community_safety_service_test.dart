import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/community_safety_service.dart';

class SafetyAdapter implements HttpClientAdapter {
  SafetyAdapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  setUpAll(
    () => initApiClient('http://example.test', includeAuthInterceptor: false),
  );

  test(
    'report sends reason detail and request id and requires server receipt',
    () async {
      RequestOptions? sent;
      dio.httpClientAdapter = SafetyAdapter((options) {
        sent = options;
        return jsonResponse({
          'id': 'r1',
          'receivedAt': '2026-09-11T12:00:00Z',
        }, status: 201);
      });
      final receipt = await CommunitySafetyService().reportPost(
        postId: 'post-1',
        reason: 'SPAM',
        detail: ' 내용 ',
        requestId: 'unique',
      );
      expect(sent!.method, 'POST');
      expect(sent!.path, '/api/v1/posts/post-1/reports');
      expect(sent!.data, {
        'reason': 'SPAM',
        'detail': '내용',
        'requestId': 'unique',
      });
      expect(receipt.id, 'r1');
      expect(receipt.receivedAt.isUtc, isTrue);
    },
  );

  test(
    'missing API and incomplete response cannot be a report success',
    () async {
      final service = CommunitySafetyService();
      Future<ReportReceipt> send() => service.reportPost(
        postId: 'post',
        reason: 'OTHER',
        detail: '사유',
        requestId: 'same-id',
      );
      dio.httpClientAdapter = SafetyAdapter(
        (_) => jsonResponse({}, status: 404),
      );
      await expectLater(send(), throwsA(isA<DioException>()));
      dio.httpClientAdapter = SafetyAdapter((_) => jsonResponse({}));
      await expectLater(send(), throwsA(isA<FormatException>()));
    },
  );

  test(
    'list decodes users and block mutations require confirmed response',
    () async {
      final sent = <RequestOptions>[];
      dio.httpClientAdapter = SafetyAdapter((options) {
        sent.add(options);
        return options.method == 'GET'
            ? jsonResponse({
                'items': [
                  {'userId': 'u1', 'nickname': '집사'},
                  {'userId': 'u2', 'nickname': ''},
                ],
              })
            : ResponseBody.fromString('', 204);
      });
      final service = CommunitySafetyService();
      final users = await service.getBlockedUsers();
      expect(users.map((u) => u.nickname), ['집사', '익명집사']);
      await service.block('u1');
      await service.unblock('u1');
      expect(sent.map((r) => '${r.method} ${r.path}'), [
        'GET /api/v1/users/me/blocks',
        'PUT /api/v1/users/me/blocks/u1',
        'DELETE /api/v1/users/me/blocks/u1',
      ]);
      dio.httpClientAdapter = SafetyAdapter(
        (_) => jsonResponse({}, status: 202),
      );
      await expectLater(service.block('u1'), throwsA(isA<FormatException>()));
      dio.httpClientAdapter = SafetyAdapter(
        (_) => jsonResponse({}, status: 404),
      );
      await expectLater(service.unblock('u1'), throwsA(isA<DioException>()));
    },
  );

  test('malformed block list is failure rather than empty state', () async {
    dio.httpClientAdapter = SafetyAdapter(
      (_) => jsonResponse({
        'items': [{}],
      }),
    );
    await expectLater(
      CommunitySafetyService().getBlockedUsers(),
      throwsA(isA<FormatException>()),
    );
  });
}
