import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/wallet_expense_service.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
  });

  test('listExpenses sends query and parses list response', () async {
    RequestOptions? captured;
    dio.httpClientAdapter = _CannedAdapter((options) {
      captured = options;
      return _jsonResponse(options, 200, {
        'data': {
          'items': [
            {
              'id': 17,
              'petId': 3,
              'expenseDate': '2026-06-12',
              'expenseTime': '14:30:00',
              'amount': 35000,
              'currency': 'KRW',
              'category': 'hospital',
              'categoryLabel': '\uBCD1\uC6D0',
              'itemName': 'checkup',
              'note': null,
            },
          ],
          'nextCursor': 'next',
          'hasMore': true,
        },
      });
    });

    final list = await WalletExpenseService().listExpenses(
      '3',
      cursor: 'cursor',
      limit: 10,
      from: '2026-06-01',
      to: '2026-06-30',
      category: 'hospital',
    );

    expect(captured?.path, '/api/v1/pets/3/wallet/expenses');
    expect(captured?.queryParameters['cursor'], 'cursor');
    expect(captured?.queryParameters['limit'], 10);
    expect(list.items.single.id, '17');
    expect(list.items.single.petId, '3');
    expect(list.items.single.expenseTime, '14:30:00');
    expect(list.nextCursor, 'next');
    expect(list.hasMore, isTrue);
  });

  test('create update delete and summary use wallet endpoints', () async {
    final paths = <String>[];
    Object? updateBody;
    dio.httpClientAdapter = _CannedAdapter((options) {
      paths.add('${options.method} ${options.path}');
      if (options.method == 'PUT') {
        updateBody = options.data;
      }
      if (options.path.endsWith('/summary')) {
        return _jsonResponse(options, 200, {
          'data': {
            'totalAmount': 42000,
            'count': 1,
            'currency': 'KRW',
            'from': null,
            'to': null,
            'categories': [
              {
                'category': 'medicine',
                'categoryLabel': '\uC57D',
                'amount': 42000,
                'count': 1,
              },
            ],
          },
        });
      }
      if (options.method == 'DELETE') {
        return _jsonResponse(options, 204, {});
      }
      return _jsonResponse(options, 200, {
        'data': {
          'id': 17,
          'petId': 3,
          'expenseDate': '2026-06-12',
          'expenseTime': null,
          'amount': 42000,
          'currency': 'KRW',
          'category': 'medicine',
          'categoryLabel': '\uC57D',
          'itemName': null,
          'note': null,
        },
      });
    });

    final service = WalletExpenseService();
    await service.createExpense('3', {'amount': 42000});
    await service.updateExpense('3', '17', {'itemName': null});
    await service.deleteExpense('3', '17');
    final summary = await service.getSummary('3');

    expect(paths, [
      'POST /api/v1/pets/3/wallet/expenses',
      'PUT /api/v1/pets/3/wallet/expenses/17',
      'DELETE /api/v1/pets/3/wallet/expenses/17',
      'GET /api/v1/pets/3/wallet/expenses/summary',
    ]);
    expect((updateBody as Map)['itemName'], isNull);
    expect(summary.totalAmount, 42000);
    expect(summary.categories.single.category, 'medicine');
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
