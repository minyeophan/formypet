import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/inquiry_service.dart';

class InquiryAdapter implements HttpClientAdapter {
  InquiryAdapter(this.handler);
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

ResponseBody response(Object? data, {int status = 201}) =>
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
  final draft = InquiryDraft(
    type: 'BUG',
    replyEmail: ' reply@example.com ',
    title: ' 오류 ',
    body: ' 내용 ',
  );
  test(
    'POST sends normalized fields and request ID, never client user ID',
    () async {
      RequestOptions? sent;
      dio.httpClientAdapter = InquiryAdapter((options) {
        sent = options;
        return response({'id': 'i1', 'receivedAt': '2026-09-11T12:00:00Z'});
      });
      final receipt = await InquiryService().submit(
        draft,
        requestId: 'request-1',
      );
      expect(sent!.method, 'POST');
      expect(sent!.path, '/api/v1/inquiries');
      expect(sent!.data, {
        'type': 'BUG',
        'replyEmail': 'reply@example.com',
        'title': '오류',
        'body': '내용',
        'requestId': 'request-1',
      });
      expect(receipt.id, 'i1');
      expect(receipt.receivedAt.isUtc, isTrue);
    },
  );
  for (final data in [
    null,
    <String, dynamic>{},
    {'id': 'i1'},
    {'id': '', 'receivedAt': '2026-09-11T12:00:00Z'},
    {'id': 'i1', 'receivedAt': 'invalid'},
    {'id': 'i1', 'receivedAt': '2026-02-30T12:00:00Z'},
    {'id': 'i1', 'receivedAt': '2026-13-11T12:00:00Z'},
  ]) {
    test(
      'missing or invalid receipt cannot confirm submission: $data',
      () async {
        dio.httpClientAdapter = InquiryAdapter((_) => response(data));
        await expectLater(
          InquiryService().submit(draft, requestId: 'r1'),
          throwsA(isA<FormatException>()),
        );
      },
    );
  }
  for (final status in [202, 204]) {
    test('HTTP $status is not confirmed completion', () async {
      dio.httpClientAdapter = InquiryAdapter(
        (_) => response({
          'id': 'i1',
          'receivedAt': '2026-09-11T12:00:00Z',
        }, status: status),
      );
      await expectLater(
        InquiryService().submit(draft, requestId: 'r1'),
        throwsA(isA<FormatException>()),
      );
    });
  }
  for (final status in [401, 403, 404, 409, 500]) {
    test('HTTP $status remains failure without automatic POST retry', () async {
      var calls = 0;
      dio.httpClientAdapter = InquiryAdapter((_) {
        calls++;
        return response({}, status: status);
      });
      await expectLater(
        InquiryService().submit(draft, requestId: 'r1'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1);
    });
  }
}
