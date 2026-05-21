import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/media_service.dart';
import 'package:frontend/services/record_service.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
  });

  test('uploadPetPhoto uses bytes multipart file field', () async {
    final fieldNames = <String>[];
    final filenames = <String?>[];
    dio.httpClientAdapter = _CannedAdapter((options) {
      final form = options.data as FormData;
      fieldNames.addAll(form.files.map((entry) => entry.key));
      filenames.addAll(form.files.map((entry) => entry.value.filename));
      return _jsonResponse(options, 201, {
        'data': {'url': '/api/v1/media/1'},
      });
    });

    final url = await MediaService().uploadPetPhoto(
      petId: '1',
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'pet-photo.png',
    );

    expect(url, '/api/v1/media/1');
    expect(fieldNames, ['file']);
    expect(filenames, ['pet-photo.png']);
  });

  test(
    'createRecordWithMedia uploads each file with file multipart field',
    () async {
      final uploadFieldNames = <String>[];
      final requestedPaths = <String>[];
      dio.httpClientAdapter = _CannedAdapter((options) {
        requestedPaths.add(options.path);
        if (options.path == '/api/v1/pets/1/records' &&
            options.method == 'POST') {
          return _jsonResponse(options, 201, {
            'data': {
              'id': 10,
              'petId': 1,
              'typeId': 'poop',
              'date': '2026-05-18',
              'mediaUrls': [],
              'detail': {},
            },
          });
        }
        if (options.path == '/api/v1/pets/1/records/10/media' &&
            options.method == 'POST') {
          final form = options.data as FormData;
          uploadFieldNames.addAll(form.files.map((entry) => entry.key));
          return _jsonResponse(options, 201, {
            'data': {
              'id': 20,
              'url': '/api/v1/media/20',
              'originalName': 'poop.png',
              'contentType': 'image/png',
              'fileSize': 5,
              'status': 'STORED',
            },
          });
        }
        if (options.path == '/api/v1/pets/1/records/10' &&
            options.method == 'GET') {
          return _jsonResponse(options, 200, {
            'data': {
              'id': 10,
              'petId': 1,
              'typeId': 'poop',
              'date': '2026-05-18',
              'mediaUrls': ['/api/v1/media/20', '/api/v1/media/21'],
              'detail': {},
            },
          });
        }
        fail('Unexpected request: ${options.method} ${options.path}');
      });
      final first = await _tempFile('first.png');
      final second = await _tempFile('second.png');

      final record = await RecordService().createRecordWithMedia(
        petId: '1',
        body: {'typeId': 'poop', 'date': '2026-05-18'},
        files: [first, second],
      );

      expect(record.mediaUrls, ['/api/v1/media/20', '/api/v1/media/21']);
      expect(uploadFieldNames, ['file', 'file']);
      expect(requestedPaths.where((path) => path.endsWith('/media')).length, 2);
    },
  );

  test(
    'createRecordWithMediaBytes uploads byte files with file multipart field',
    () async {
      final uploadFieldNames = <String>[];
      final uploadFilenames = <String?>[];
      final requestedPaths = <String>[];
      dio.httpClientAdapter = _CannedAdapter((options) {
        requestedPaths.add(options.path);
        if (options.path == '/api/v1/pets/1/records' &&
            options.method == 'POST') {
          return _jsonResponse(options, 201, {
            'data': {
              'id': 10,
              'petId': 1,
              'typeId': 'meal',
              'date': '2026-05-21',
              'mediaUrls': [],
              'detail': {},
            },
          });
        }
        if (options.path == '/api/v1/pets/1/records/10/media' &&
            options.method == 'POST') {
          final form = options.data as FormData;
          uploadFieldNames.addAll(form.files.map((entry) => entry.key));
          uploadFilenames.addAll(
            form.files.map((entry) => entry.value.filename),
          );
          return _jsonResponse(options, 201, {
            'data': {
              'id': 20,
              'url': '/api/v1/media/20',
              'originalName': 'meal.png',
              'contentType': 'image/png',
              'fileSize': 5,
              'status': 'STORED',
            },
          });
        }
        if (options.path == '/api/v1/pets/1/records/10' &&
            options.method == 'GET') {
          return _jsonResponse(options, 200, {
            'data': {
              'id': 10,
              'petId': 1,
              'typeId': 'meal',
              'date': '2026-05-21',
              'mediaUrls': ['/api/v1/media/20'],
              'detail': {},
            },
          });
        }
        fail('Unexpected request: ${options.method} ${options.path}');
      });

      final record = await RecordService().createRecordWithMediaBytes(
        petId: '1',
        body: {'typeId': 'meal', 'date': '2026-05-21'},
        files: [
          RecordMediaUpload(
            bytes: Uint8List.fromList([1, 2, 3]),
            filename: 'meal.png',
          ),
        ],
      );

      expect(record.mediaUrls, ['/api/v1/media/20']);
      expect(uploadFieldNames, ['file']);
      expect(uploadFilenames, ['meal.png']);
      expect(requestedPaths.where((path) => path.endsWith('/media')).length, 1);
    },
  );
}

Future<File> _tempFile(String name) async {
  final dir = await Directory.systemTemp.createTemp('petyilgi-media-test-');
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  return file.writeAsBytes(utf8.encode('image'));
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
