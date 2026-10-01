import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/services/community_service.dart';

void main() {
  setUpAll(() {
    initApiClient('https://example.test', includeAuthInterceptor: false);
  });

  test(
    'first destination response preserves a move without prior feed cache',
    () async {
      final destinationResponse = Completer<ResponseBody>();
      final destinationStarted = Completer<void>();
      dio.httpClientAdapter = _Api((request) async {
        if (request.method == 'PUT') {
          return _json({
            ..._post('moved', 'FOOD'),
            'title': 'Updated title',
            'content': 'Updated body',
          });
        }
        if (request.queryParameters['category'] == 'FOOD') {
          destinationStarted.complete();
          return destinationResponse.future;
        }
        return _feed(
          request.queryParameters['category'] == 'CARE'
              ? [_post('moved', 'CARE')]
              : [_post('moved', 'CARE'), _post('unchanged', 'FOOD')],
        );
      });
      final notifier = CommunityNotifier(CommunityService());
      addTearDown(notifier.dispose);
      await _initialFeed(notifier);
      await notifier.loadFeed(feedKey: 'CARE');
      expect(notifier.state.postsByFeedKey.containsKey('FOOD'), isFalse);

      final pending = notifier.loadFeed(feedKey: 'FOOD');
      await destinationStarted.future;
      await notifier.updatePost(
        'moved',
        title: 'Updated title',
        content: 'Updated body',
        category: 'FOOD',
      );
      expect(notifier.state.postsByFeedKey.containsKey('FOOD'), isFalse);
      expect(notifier.state.postsById['moved']!.category, 'FOOD');

      destinationResponse.complete(_feed([]));
      await pending;

      expect(notifier.state.postsForFeed('FOOD').map((post) => post.id), [
        'moved',
      ]);
      expect(notifier.state.postsForFeed('FOOD').single.title, 'Updated title');
      expect(notifier.state.postsForFeed('CARE'), isEmpty);
      expect(notifier.state.postsById['moved']!.content, 'Updated body');
    },
  );

  for (final boundary in [
    'source feed',
    'destination feed',
    'search',
    'detail',
  ]) {
    test('late $boundary response preserves completed category edit', () async {
      final staleResponse = Completer<ResponseBody>();
      final readStarted = Completer<void>();
      var holdReads = false;
      dio.httpClientAdapter = _Api((request) async {
        if (request.method == 'PUT') {
          return _json({
            ..._post('one', 'FOOD'),
            'title': 'Updated title',
            'content': 'Updated body',
          });
        }
        if (holdReads) {
          readStarted.complete();
          return staleResponse.future;
        }
        return _feed(
          request.queryParameters['category'] == 'FOOD'
              ? []
              : [_post('one', 'CARE')],
        );
      });
      final notifier = CommunityNotifier(CommunityService());
      addTearDown(notifier.dispose);
      await _initialFeed(notifier);
      for (final key in ['CARE', 'FOOD', 'all']) {
        await notifier.loadFeed(feedKey: key);
      }
      holdReads = true;
      final Future<Object?> pending = switch (boundary) {
        'source feed' => notifier.loadFeed(feedKey: 'CARE', refresh: true),
        'destination feed' => notifier.loadFeed(feedKey: 'FOOD', refresh: true),
        'search' => notifier.searchPosts('Title'),
        _ => notifier.loadPost('one'),
      };
      await readStarted.future;
      await notifier.updatePost(
        'one',
        title: 'Updated title',
        content: 'Updated body',
        category: 'FOOD',
      );
      expect(notifier.state.postsForFeed('CARE'), isEmpty);
      expect(notifier.state.postsForFeed('FOOD').single.category, 'FOOD');

      staleResponse.complete(
        boundary == 'detail'
            ? _json(_post('one', 'CARE'))
            : _feed(
                boundary == 'destination feed' ? [] : [_post('one', 'CARE')],
              ),
      );
      final result = await pending;

      expect(notifier.state.postsForFeed('CARE'), isEmpty);
      expect(notifier.state.postsForFeed('FOOD').map((post) => post.id), [
        'one',
      ]);
      for (final key in ['FOOD', 'all', 'popular']) {
        expect(notifier.state.postsForFeed(key).single.category, 'FOOD');
        expect(notifier.state.postsForFeed(key).single.title, 'Updated title');
      }
      expect(notifier.state.postsById['one']!.category, 'FOOD');
      expect(notifier.state.postsById['one']!.content, 'Updated body');
      if (boundary == 'search') {
        expect((result as List<Post>).single.category, 'FOOD');
        expect(result.single.title, 'Updated title');
      } else if (boundary == 'detail') {
        expect((result as Post).category, 'FOOD');
        expect(result.title, 'Updated title');
      }
    });
  }

  test('fresh detail reads after an edit can update server values', () async {
    dio.httpClientAdapter = _Api((request) async {
      if (request.method == 'PUT') return _json(_post('one', 'FOOD'));
      if (request.path.endsWith('/one')) {
        return _json({
          ..._post('one', 'FOOD'),
          'title': 'New server title',
          'likesCount': 12,
        });
      }
      return _feed([_post('one', 'CARE')]);
    });
    final notifier = CommunityNotifier(CommunityService());
    addTearDown(notifier.dispose);
    await _initialFeed(notifier);
    await notifier.updatePost(
      'one',
      title: 'Title',
      content: 'Body',
      category: 'FOOD',
    );

    final detail = await notifier.loadPost('one');

    expect(detail.title, 'New server title');
    expect(notifier.state.postsById['one']!.likesCount, 12);
  });

  test(
    'creating from popular refetches server order instead of prepending',
    () async {
      var saved = false;
      dio.httpClientAdapter = _Api((request) async {
        if (request.method == 'POST') {
          saved = true;
          return _json(_post('new', 'FOOD'));
        }
        return _feed([
          {..._post('leader', 'CARE'), 'likesCount': 10},
          if (saved) _post('new', 'FOOD'),
        ]);
      });
      final notifier = CommunityNotifier(CommunityService());
      addTearDown(notifier.dispose);
      await _initialFeed(notifier);

      await notifier.createPost(
        title: 'Food',
        content: 'Body',
        category: 'FOOD',
      );

      expect(notifier.state.postsForFeed('popular').map((post) => post.id), [
        'leader',
        'new',
      ]);
    },
  );

  test(
    'popular refresh failure keeps successful creation and prior ranking',
    () async {
      var saved = false;
      dio.httpClientAdapter = _Api((request) async {
        if (request.method == 'POST') {
          saved = true;
          return _json(_post('new', 'FOOD'));
        }
        if (saved) return ResponseBody.fromString('{}', 503);
        return _feed([
          {..._post('leader', 'CARE'), 'likesCount': 10},
        ]);
      });
      final notifier = CommunityNotifier(CommunityService());
      addTearDown(notifier.dispose);
      await _initialFeed(notifier);

      final created = await notifier.createPost(
        title: 'Food',
        content: 'Body',
        category: 'FOOD',
      );

      expect(created.id, 'new');
      expect(notifier.state.postsById['new']!.category, 'FOOD');
      expect(
        notifier.state.failureForFeed('popular')?.requestKind,
        CommunityFeedRequestKind.refresh,
      );
      expect(notifier.state.postsForFeed('popular').map((post) => post.id), [
        'leader',
      ]);
    },
  );

  test(
    'creation during popular fetch refreshes after the earlier response',
    () async {
      final firstFeed = Completer<ResponseBody>();
      var gets = 0;
      dio.httpClientAdapter = _Api((request) async {
        if (request.method == 'POST') return _json(_post('new', 'FOOD'));
        if (++gets == 1) return firstFeed.future;
        return _feed([
          {..._post('leader', 'CARE'), 'likesCount': 10},
          _post('new', 'FOOD'),
        ]);
      });
      final notifier = CommunityNotifier(CommunityService());
      addTearDown(notifier.dispose);

      await notifier.createPost(
        title: 'Food',
        content: 'Body',
        category: 'FOOD',
      );
      firstFeed.complete(
        _feed([
          {..._post('leader', 'CARE'), 'likesCount': 10},
        ]),
      );
      await _initialFeed(notifier);

      expect(notifier.state.postsForFeed('popular').map((post) => post.id), [
        'leader',
        'new',
      ]);
    },
  );

  test(
    'creating in another category only inserts into matching loaded feeds',
    () async {
      dio.httpClientAdapter = _Api((request) async {
        if (request.method == 'GET') return _feed([]);
        return _json(_post('new', 'FOOD'));
      });
      final notifier = CommunityNotifier(CommunityService());
      addTearDown(notifier.dispose);
      await _initialFeed(notifier);
      await notifier.loadFeed(feedKey: 'all');
      await notifier.loadFeed(feedKey: 'FOOD');
      await notifier.setFeedKey('CARE');

      await notifier.createPost(
        title: 'Food',
        content: 'Body',
        category: 'FOOD',
      );

      expect(notifier.state.postsForFeed('CARE'), isEmpty);
      expect(notifier.state.postsForFeed('all').map((post) => post.id), [
        'new',
      ]);
      expect(notifier.state.postsForFeed('FOOD').map((post) => post.id), [
        'new',
      ]);
      expect(notifier.state.postsForFeed('popular'), isEmpty);
      expect(notifier.state.postsById['new']!.category, 'FOOD');
    },
  );

  test(
    'category edit moves post out of old feeds and into loaded destination',
    () async {
      dio.httpClientAdapter = _Api((request) async {
        if (request.method == 'PUT') return _json(_post('one', 'FOOD'));
        return _feed(
          request.queryParameters['category'] == 'FOOD'
              ? [_post('two', 'FOOD')]
              : [_post('one', 'CARE')],
        );
      });
      final notifier = CommunityNotifier(CommunityService());
      addTearDown(notifier.dispose);
      await _initialFeed(notifier);
      for (final key in ['all', 'CARE', 'FOOD']) {
        await notifier.loadFeed(feedKey: key);
      }

      await notifier.updatePost(
        'one',
        title: 'Food',
        content: 'Body',
        category: 'FOOD',
      );

      expect(notifier.state.postsForFeed('CARE'), isEmpty);
      expect(notifier.state.postsForFeed('FOOD').map((post) => post.id), [
        'one',
        'two',
      ]);
      expect(notifier.state.postsForFeed('all').single.category, 'FOOD');
      expect(notifier.state.postsForFeed('popular').single.category, 'FOOD');
      await notifier.updatePost(
        'one',
        title: 'Food again',
        content: 'Body',
        category: 'FOOD',
      );
      expect(notifier.state.postsForFeed('FOOD').map((post) => post.id), [
        'one',
        'two',
      ]);
    },
  );

  test(
    'feed response that overlaps a like keeps server mutation values',
    () async {
      final response = Completer<ResponseBody>();
      var gets = 0;
      dio.httpClientAdapter = _Api((request) async {
        if (request.method == 'POST') {
          return _json({'liked': true, 'likesCount': 9});
        }
        if (++gets > 1) return response.future;
        return _feed([_post('one', 'CARE')]);
      });
      final notifier = CommunityNotifier(CommunityService());
      addTearDown(notifier.dispose);
      await _initialFeed(notifier);
      final refresh = notifier.loadFeed(refresh: true);
      await notifier.toggleLike('one');
      response.complete(_feed([_post('one', 'CARE')]));
      await refresh;

      expect(notifier.state.postsForFeed('popular').single.liked, isTrue);
      expect(notifier.state.postsById['one']!.likesCount, 9);
    },
  );
}

Future<void> _initialFeed(CommunityNotifier notifier) async {
  while (notifier.state.isLoadingFeed('popular')) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Map<String, dynamic> _post(String id, String category) => {
  'id': id,
  'userId': 'author',
  'authorNickname': 'Author',
  'authorProfileImageUrl': null,
  'title': 'Title',
  'content': 'Body',
  'category': category,
  'likesCount': 0,
  'liked': false,
  'commentsCount': 0,
  'mediaUrls': <String>[],
  'poll': null,
  'createdAt': '2026-09-08T12:00:00',
};

ResponseBody _feed(List<Map<String, dynamic>> posts) =>
    _json({'items': posts, 'nextCursor': null});

ResponseBody _json(Map<String, dynamic> data) => ResponseBody.fromString(
  jsonEncode({'data': data}),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Api implements HttpClientAdapter {
  _Api(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}
