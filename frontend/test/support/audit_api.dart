import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:frontend/core/api_client.dart';

class AuditApi implements HttpClientAdapter {
  FutureOr<Object?> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  AuditApi(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    options.extra['_noTransientRetry'] = true;
    requests.add(options);
    final data = await respond(options);
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void useAuditApi(AuditApi api) => dio.httpClientAdapter = api;

Future<void> until(bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    if (ready()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Expected async operation did not become ready');
}

Map<String, Object?> auditPet(String id) => {
  'id': id,
  'name': 'Pet $id',
  'species': 'dog',
  'birthDate': null,
  'accentColor': '#FF8A65',
  'bgLight': '#FFF3E0',
};

Map<String, Object?> auditRecord(String id, String petId) => {
  'id': id,
  'petId': petId,
  'typeId': 'weight',
  'date': '2026-09-08',
  'time': '09:00',
  'detail': {'weight': 4},
};

Map<String, Object?> auditNotification(String id) => {
  'id': id,
  'type': 'POST_LIKE',
  'title': '알림 $id',
  'body': '내용 $id',
  'postId': '9',
  'readAt': null,
  'createdAt': '2026-09-08T09:00:00',
};

Map<String, Object?> auditFeed(List<String> ids, {String? cursor}) => {
  'items': ids.map(auditNotification).toList(),
  'nextCursor': cursor,
  'hasMore': cursor != null,
  'unreadCount': ids.length,
};

Object? auditDefaultResponse(RequestOptions request) {
  final path = request.path;
  if (path == '/api/v1/users/me') {
    return {'id': 'user-a', 'email': 'a@example.test', 'nickname': 'A'};
  }
  if (path == '/api/v1/pets') return [auditPet('a'), auditPet('b')];
  if (path.endsWith('/routines/today')) {
    return {
      'routines': [],
      'summary': {'total': 0, 'done': 0, 'rate': 0},
    };
  }
  if (path.endsWith('/records') ||
      path.endsWith('/routines') ||
      path.endsWith('/care-schedules')) {
    return [];
  }
  if (path == '/api/v1/notifications') return auditFeed(['old']);
  if (request.method != 'GET') return null;
  throw StateError('Unexpected request: ${request.method} $path');
}
