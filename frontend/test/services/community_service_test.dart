import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/services/community_service.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  setUpAll(() {
    initApiClient('http://example.test', includeAuthInterceptor: false);
  });

  test('getFeed sends sort without category for popular feed', () async {
    RequestOptions? captured;
    dio.httpClientAdapter = _CannedAdapter((options) {
      captured = options;
      return _jsonResponse(options, 200, {
        'data': {'items': [], 'nextCursor': 'next'},
      });
    });

    final feed = await CommunityService().getFeed(
      sort: CommunityFeedSort.popular,
      cursor: '10:post-1',
    );

    expect(feed.nextCursor, 'next');
    expect(captured?.path, '/api/v1/posts');
    expect(captured?.queryParameters['sort'], 'popular');
    expect(captured?.queryParameters['cursor'], '10:post-1');
    expect(captured?.queryParameters.containsKey('category'), isFalse);
  });

  test('getFeed sends latest sort and category for category feed', () async {
    RequestOptions? captured;
    dio.httpClientAdapter = _CannedAdapter((options) {
      captured = options;
      return _jsonResponse(options, 200, {
        'data': {'items': [], 'nextCursor': null},
      });
    });

    await CommunityService().getFeed(
      category: 'CARE',
      sort: CommunityFeedSort.latest,
    );

    expect(captured?.queryParameters['sort'], 'latest');
    expect(captured?.queryParameters['category'], 'CARE');
  });

  test(
    'createPost always sends multipart payload with poll and files',
    () async {
      FormData? captured;
      dio.httpClientAdapter = _CannedAdapter((options) {
        captured = options.data as FormData;
        return _jsonResponse(options, 201, {
          'data': {
            'id': 'post-1',
            'userId': 'user-1',
            'authorNickname': 'Momo',
            'content': 'content',
            'category': 'CARE',
            'mediaUrls': ['/media/photo.png'],
            'createdAt': '2026-05-21T12:00:00',
          },
        });
      });

      final post = await CommunityService().createPost(
        content: 'content',
        title: 'title',
        category: 'CARE',
        files: [
          XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            name: 'photo.png',
            path: 'photo.png',
            mimeType: 'image/png',
          ),
        ],
        poll: const PollDraft(question: 'Pick one', options: ['A', 'B']),
      );

      expect(post.imageUrls, ['/media/photo.png']);
      final payloadEntry = captured!.fields.singleWhere(
        (e) => e.key == 'payload',
      );
      final payload = jsonDecode(payloadEntry.value) as Map<String, dynamic>;
      expect(payload['title'], 'title');
      expect(payload['category'], 'CARE');
      expect(payload['poll']['question'], 'Pick one');
      expect(payload['poll']['options'], ['A', 'B']);
      expect(captured!.files.map((entry) => entry.key), ['files']);
      expect(captured!.files.single.value.filename, 'photo.png');
    },
  );

  test('createPost sends multipart payload even without files', () async {
    Object? capturedData;
    dio.httpClientAdapter = _CannedAdapter((options) {
      capturedData = options.data;
      return _jsonResponse(options, 201, {
        'data': {
          'id': 'post-1',
          'userId': 'user-1',
          'authorNickname': 'Momo',
          'content': 'content',
          'category': 'CARE',
          'mediaUrls': [],
          'createdAt': '2026-05-21T12:00:00',
        },
      });
    });

    await CommunityService().createPost(content: 'content', category: 'CARE');

    expect(capturedData, isA<FormData>());
    expect((capturedData as FormData).fields.map((e) => e.key), ['payload']);
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
