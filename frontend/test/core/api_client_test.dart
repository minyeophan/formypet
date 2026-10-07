import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';

void main() {
  test('parseApiError preserves ProblemDetail errorCode', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/v1/pets/1/wallet/expenses'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/pets/1/wallet/expenses'),
        statusCode: 404,
        data: {
          'title': 'Not Found',
          'detail': 'Wallet expense not found.',
          'errorCode': 'WALLET_EXPENSE_NOT_FOUND',
        },
      ),
    );

    final parsed = parseApiError(error);

    expect(parsed.statusCode, 404);
    expect(parsed.title, 'Not Found');
    expect(parsed.detail, 'Wallet expense not found.');
    expect(parsed.errorCode, 'WALLET_EXPENSE_NOT_FOUND');
  });

  test('media errors explain quota and request limits in Korean', () {
    final request = RequestOptions(path: '/api/v1/media');
    final quota = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 409,
        data: {'errorCode': 'MEDIA_QUOTA_EXCEEDED'},
      ),
    );
    final limited = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 429),
    );

    expect(mediaUploadErrorMessage(quota, fallback: 'fallback'), contains('저장 한도'));
    expect(mediaUploadErrorMessage(limited, fallback: 'fallback'), contains('요청이 많아요'));
  });

  test('GET requests retry one transient failure', () async {
    initApiClient('http://example.test', includeAuthInterceptor: false);
    var attempts = 0;
    dio.httpClientAdapter = _RetryAdapter(() {
      attempts++;
      if (attempts == 1) {
        throw DioException(
          requestOptions: RequestOptions(path: '/retry'),
          type: DioExceptionType.connectionError,
        );
      }
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    final response = await dio.get('/retry');

    expect(response.statusCode, 200);
    expect(attempts, 2);
  });
}

class _RetryAdapter implements HttpClientAdapter {
  final ResponseBody Function() handler;

  _RetryAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler();

  @override
  void close({bool force = false}) {}
}
