import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:frontend/core/api_client.dart';

Map<String, dynamic> expenseJson(
  String id,
  String petId, {
  int amount = 1000,
  String? date,
}) => {
  'id': id,
  'petId': petId,
  'expenseDate': date ?? DateTime.now().toIso8601String().substring(0, 10),
  'expenseTime': '09:00',
  'amount': amount,
  'currency': 'KRW',
  'category': 'food',
  'categoryLabel': '사료',
  'itemName': id,
  'note': null,
};

class WalletTestApi implements HttpClientAdapter {
  WalletTestApi(this.rows) {
    if (!_initialized) {
      initApiClient('http://wallet.test', includeAuthInterceptor: false);
      _initialized = true;
    }
    dio.httpClientAdapter = this;
  }

  static bool _initialized = false;

  final List<Map<String, dynamic>> rows;
  final requests = <RequestOptions>[];
  bool summaryFails = false;
  bool listFails = false;
  int? failingListOffset;
  bool mutationFails = false;
  Future<void> Function(RequestOptions)? beforeResponse;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final parts = options.path.split('/');
    final petId = parts[4];
    final id = parts.length > 7 ? parts[7] : null;
    final petRows = rows.where((r) => r['petId'] == petId).toList();
    Object? data;
    var status = 200;
    if (options.method != 'GET' && mutationFails) {
      status = 500;
    } else if (id == 'summary') {
      status = summaryFails ? 500 : 200;
      data = {
        'totalAmount': petRows.fold<int>(0, (s, r) => s + (r['amount'] as int)),
        'count': petRows.length,
        'currency': 'KRW',
        'from': null,
        'to': null,
        'categories': [],
      };
    } else if (options.method == 'GET' && id == null) {
      if (listFails) status = 500;
      final offset = int.parse(options.queryParameters['cursor'] ?? '0');
      if (failingListOffset != null && offset >= failingListOffset!) {
        status = 500;
      }
      final limit = options.queryParameters['limit'] as int? ?? 20;
      final page = petRows.skip(offset).take(limit).map((r) => {...r}).toList();
      final more = offset + page.length < petRows.length;
      data = {
        'items': page,
        'hasMore': more,
        'nextCursor': more ? '${offset + page.length}' : null,
      };
    } else if (options.method == 'POST') {
      final row = {
        ...expenseJson('created', petId),
        ...options.data as Map<String, dynamic>,
      };
      rows.insert(0, row);
      data = {...row};
    } else {
      final index = rows.indexWhere(
        (r) => r['id'] == id && r['petId'] == petId,
      );
      if (index < 0) {
        status = 404;
      } else if (options.method == 'DELETE') {
        rows.removeAt(index);
        status = 204;
      } else {
        if (options.method == 'PUT') {
          rows[index] = {
            ...rows[index],
            ...options.data as Map<String, dynamic>,
          };
        }
        data = {...rows[index]};
      }
    }
    await beforeResponse?.call(options);
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
