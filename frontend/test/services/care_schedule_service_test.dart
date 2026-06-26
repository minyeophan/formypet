import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/care_schedule.dart';
import 'package:frontend/services/care_schedule_service.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
  });

  test('list and get schedules use care schedule endpoints', () async {
    final paths = <String>[];
    dio.httpClientAdapter = _CannedAdapter((options) {
      paths.add('${options.method} ${options.path}');
      final item = _jsonSchedule('17');
      return _jsonResponse(options, 200, {
        'data': options.path.endsWith('/17') ? item : [item],
      });
    });

    final service = CareScheduleService();
    final list = await service.getSchedules('3');
    final detail = await service.getSchedule('3', '17');

    expect(paths, [
      'GET /api/v1/pets/3/care-schedules',
      'GET /api/v1/pets/3/care-schedules/17',
    ]);
    expect(list.single.id, '17');
    expect(detail.startTime, '09:05');
  });

  test(
    'create update and delete use request body without identity fields',
    () async {
      final paths = <String>[];
      Object? createBody;
      Object? updateBody;
      dio.httpClientAdapter = _CannedAdapter((options) {
        paths.add('${options.method} ${options.path}');
        if (options.method == 'POST') createBody = options.data;
        if (options.method == 'PUT') updateBody = options.data;
        if (options.method == 'DELETE') return _jsonResponse(options, 204, {});
        return _jsonResponse(options, 200, {'data': _jsonSchedule('17')});
      });

      final service = CareScheduleService();
      final schedule = _schedule();
      await service.createSchedule('3', schedule);
      await service.updateSchedule('3', '17', schedule);
      await service.deleteSchedule('3', '17');

      expect(paths, [
        'POST /api/v1/pets/3/care-schedules',
        'PUT /api/v1/pets/3/care-schedules/17',
        'DELETE /api/v1/pets/3/care-schedules/17',
      ]);
      expect((createBody as Map).containsKey('id'), isFalse);
      expect((createBody as Map).containsKey('petId'), isFalse);
      expect((createBody as Map).containsKey('createdAt'), isFalse);
      expect((updateBody as Map)['startTime'], '09:05');
    },
  );
}

CareSchedule _schedule() => const CareSchedule(
  id: 'local-1',
  petId: '3',
  categoryId: 'hospital',
  title: 'Checkup',
  startDate: '2026-07-01',
  startTime: '09:05',
  endDate: '2026-07-01',
  endTime: '10:30',
  allDay: false,
  place: 'Clinic',
  memo: 'Bring note',
  reminder: '1 hour before',
  createdAt: '2026-06-01T00:00:00.000',
);

Map<String, dynamic> _jsonSchedule(String id) => {
  'id': id,
  'petId': 3,
  'categoryId': 'hospital',
  'title': 'Checkup',
  'startDate': '2026-07-01',
  'startTime': '09:05',
  'endDate': '2026-07-01',
  'endTime': '10:30',
  'allDay': false,
  'place': 'Clinic',
  'memo': 'Bring note',
  'reminder': '1 hour before',
  'createdAt': '2026-06-01T00:00:00.000',
};

ResponseBody _jsonResponse(
  RequestOptions options,
  int statusCode,
  Object body,
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
