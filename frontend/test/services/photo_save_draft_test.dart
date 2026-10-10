import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/photo_preparation.dart';
import 'package:frontend/services/photo_save_draft.dart';

class Adapter implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    if (s != null) {
      await s.drain<void>();
    }
    return respond(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody ok(dynamic data) => ResponseBody.fromString(
  jsonEncode({'data': data}),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);
DioException lost(RequestOptions o) =>
    DioException(requestOptions: o, type: DioExceptionType.receiveTimeout);
void main() {
  setUpAll(() => initApiClient('http://test', includeAuthInterceptor: false));
  const body = {'name': 'first'};
  final photos = [
    PreparedPhoto(Uint8List.fromList([1]), 'a.png', 'image/png'),
    PreparedPhoto(Uint8List.fromList([2]), 'b.png', 'image/png'),
  ];
  test(
    'lost create response replays frozen payload and key before edited update',
    () async {
      final draft = PhotoSaveDraft();
      final requests = <RequestOptions>[];
      var lose = true;
      dio.httpClientAdapter = Adapter((o) {
        requests.add(o);
        if (o.method == 'POST' && lose) {
          lose = false;
          throw lost(o);
        }
        return ok({'id': 1});
      });
      Future<void> save(Map<String, dynamic> b) async {
        await draft.save(
          path: '/pets',
          body: b,
          photos: [],
          current: () => true,
        );
      }

      await expectLater(save(body), throwsA(isA<DioException>()));
      await save({'name': 'edited'});
      expect(requests.map((r) => r.method), ['POST', 'POST', 'PUT', 'GET']);
      expect(requests[0].data, requests[1].data);
      expect(
        requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key'],
      );
      expect(requests[2].data, {'name': 'edited'});
    },
  );
  test(
    'partial upload resumes failed index, refresh failure retries GET only',
    () async {
      final draft = PhotoSaveDraft();
      final keys = <String>[];
      var failUpload = true;
      var failGet = true;
      var creates = 0;
      dio.httpClientAdapter = Adapter((o) {
        if (o.path.endsWith('/media')) {
          keys.add(o.headers['Idempotency-Key'] as String);
          if (keys.length == 2 && failUpload) {
            failUpload = false;
            throw lost(o);
          }
        } else if (o.method == 'POST') {
          creates++;
        }
        if (o.method == 'GET' && failGet) {
          return ResponseBody.fromString('{}', 503);
        }
        return ok({'id': 1});
      });
      Future<void> save() async {
        await draft.save(
          path: '/pets',
          body: body,
          photos: photos,
          current: () => true,
        );
      }

      await expectLater(save(), throwsA(isA<DioException>()));
      expect(draft.retryTarget, PhotoRetryTarget.upload);
      await expectLater(save(), throwsA(isA<DioException>()));
      expect(draft.retryTarget, PhotoRetryTarget.refresh);
      failGet = false;
      await save();
      expect(creates, 1);
      expect(keys.length, 3);
      expect(keys[1], keys[2]);
      expect(keys[0], isNot(keys[1]));
    },
  );
  test(
    'definitively rejected saved photo can be replaced without recreating',
    () async {
      final draft = RecordPhotoDraft();
      final methods = <String>[];
      final photoKeys = <String>[];
      var createCount = 0;
      var reject = true;
      dio.httpClientAdapter = Adapter((o) {
        methods.add(o.method);
        if (o.path.endsWith('/media')) {
          photoKeys.add(o.headers['Idempotency-Key'] as String);
          if (reject) {
            reject = false;
            return ResponseBody.fromString(
              jsonEncode({'errorCode': 'MEDIA_INVALID_FILE'}),
              400,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
        } else if (o.method == 'POST') {
          createCount++;
        }
        return ok({
          'id': 7,
          'petId': 'pet',
          'typeId': 'meal',
          'date': '2026-10-10',
        });
      });

      await expectLater(
        draft.saveRecord(
          petId: 'pet',
          body: body,
          photos: photos.take(1).toList(),
          current: () => true,
        ),
        throwsA(isA<DioException>()),
      );
      expect(draft.savedId, '7');
      expect(draft.canReplacePendingPhotos, isTrue);
      draft.replacePendingPhotos([
        PreparedPhoto(Uint8List.fromList([9]), 'corrected.png', 'image/png'),
      ]);
      await draft.saveRecord(
        petId: 'pet',
        body: body,
        photos: const [],
        current: () => true,
      );

      expect(createCount, 1);
      expect(methods, ['POST', 'POST', 'POST', 'GET']);
      expect(photoKeys, hasLength(2));
      expect(photoKeys.first, isNot(photoKeys.last));
      expect(draft.status, PhotoSaveStatus.complete);
    },
  );
  test('account switch after create prevents upload and read', () async {
    var current = true;
    final paths = <String>[];
    dio.httpClientAdapter = Adapter((o) {
      paths.add(o.path);
      current = false;
      return ok({'id': 1});
    });
    await expectLater(
      PhotoSaveDraft().save(
        path: '/pets',
        body: body,
        photos: photos,
        current: () => current,
      ),
      throwsStateError,
    );
    expect(paths, ['/pets']);
  });
  test(
    'lost existing update reconciles frozen PUT before later edits',
    () async {
      final draft = PhotoSaveDraft();
      final payloads = <dynamic>[];
      var lose = true;
      dio.httpClientAdapter = Adapter((o) {
        if (o.method == 'PUT') {
          payloads.add(o.data);
          if (lose) {
            lose = false;
            throw lost(o);
          }
        }
        return ok({'id': 1});
      });
      Future<void> save(Map<String, dynamic> b) async {
        await draft.save(
          path: '/pets',
          existingId: '1',
          body: b,
          photos: [],
          current: () => true,
        );
      }

      await expectLater(save(body), throwsA(isA<DioException>()));
      await save({'name': 'edited'});
      expect(payloads, [
        body,
        body,
        {'name': 'edited'},
      ]);
    },
  );

  test(
    'missing saved pet in refresh list retries read without another mutation',
    () async {
      final draft = PhotoSaveDraft();
      final methods = <String>[];
      var empty = true;
      dio.httpClientAdapter = Adapter((o) {
        methods.add(o.method);
        return ok(
          o.method == 'GET'
              ? (empty
                    ? []
                    : [
                        {'id': 1},
                      ])
              : {'id': 1, 'petId': 2, 'typeId': 'meal', 'date': '2026-10-10'},
        );
      });
      Future<void> save() async {
        await draft.save(
          path: '/pets',
          body: body,
          photos: [],
          current: () => true,
          refreshFromList: true,
        );
      }

      await expectLater(save(), throwsStateError);
      expect(draft.status, PhotoSaveStatus.savedNeedsRefresh);
      empty = false;
      await save();
      expect(methods, ['POST', 'GET', 'GET']);
    },
  );

  for (final existing in [false, true]) {
    test(
      'definitive validation rejection permits correction; existing=$existing',
      () async {
        final draft = PhotoSaveDraft();
        final payloads = <dynamic>[];
        final keys = <dynamic>[];
        var reject = true;
        dio.httpClientAdapter = Adapter((o) {
          if (o.method != 'GET') {
            payloads.add(o.data);
            keys.add(o.headers['Idempotency-Key']);
            if (reject) {
              reject = false;
              return ResponseBody.fromString('{}', 400);
            }
          }
          return ok({'id': 1});
        });
        Future<void> save(Map<String, dynamic> b) async {
          await draft.save(
            path: '/pets',
            existingId: existing ? '1' : null,
            body: b,
            photos: [],
            current: () => true,
          );
        }

        await expectLater(
          save({'name': 'invalid'}),
          throwsA(isA<DioException>()),
        );
        expect(draft.status, PhotoSaveStatus.ready);
        await save({'name': 'corrected'});
        expect(payloads, [
          {'name': 'invalid'},
          {'name': 'corrected'},
        ]);
        if (!existing) expect(keys[0], isNot(keys[1]));
      },
    );
  }
}
