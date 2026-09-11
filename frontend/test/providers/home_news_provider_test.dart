import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/home_news_provider.dart';
import 'package:frontend/services/community_service.dart';

void main() {
  test(
    'initial failure can be retried with fewer than three news posts',
    () async {
      final service = _FakeCommunityService();
      final notifier = HomeNewsNotifier(service);
      addTearDown(notifier.dispose);
      final first = notifier.load();
      service.fail(Exception('offline'));
      await expectLater(first, throwsException);
      expect(notifier.state.initialError, isNotNull);
      final retry = notifier.load();
      service.complete([_post('1')]);
      await retry;
      expect(notifier.state.posts, hasLength(1));
      expect(notifier.state.initialError, isNull);
    },
  );

  test('request finishing after disposal does not update state', () async {
    final service = _FakeCommunityService();
    final notifier = HomeNewsNotifier(service);
    final request = notifier.load();
    notifier.dispose();
    service.complete([_post('1')]);
    await request;
  });

  test('loads news feed with limit three and coalesces requests', () async {
    final service = _FakeCommunityService();
    final notifier = HomeNewsNotifier(service);

    final first = notifier.load();
    final second = notifier.load();

    expect(identical(first, second), isTrue);
    expect(service.requests, [('NEWS', CommunityFeedSort.latest, 3)]);
    service.complete([_post('1'), _post('2'), _post('3'), _post('4')]);
    await first;

    expect(notifier.state.posts.map((post) => post.id), ['1', '2', '3']);
    expect(notifier.state.isInitialLoading, isFalse);
  });

  test('refresh failure preserves existing posts', () async {
    final service = _FakeCommunityService();
    final notifier = HomeNewsNotifier(service);
    final initial = notifier.load();
    service.complete([_post('1')]);
    await initial;

    final refresh = notifier.refresh();
    service.fail(Exception('offline'));
    await expectLater(refresh, throwsException);

    expect(notifier.state.posts.map((post) => post.id), ['1']);
    expect(notifier.state.initialError, isNull);
    expect(notifier.state.isRefreshing, isFalse);
  });
}

Post _post(String id) => Post(
  id: id,
  userId: 'user',
  authorNickname: 'author',
  title: 'title $id',
  content: 'content',
  category: 'NEWS',
  likesCount: 1,
  liked: false,
  commentsCount: 2,
  imageUrls: const [],
  createdAt: '2026-07-01T00:00:00Z',
);

class _FakeCommunityService extends CommunityService {
  final requests = <(String?, CommunityFeedSort, int)>[];
  Completer<PostFeed>? _completer;

  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) {
    requests.add((category, sort, limit));
    _completer = Completer<PostFeed>();
    return _completer!.future;
  }

  void complete(List<Post> posts) {
    _completer!.complete(PostFeed(items: posts));
  }

  void fail(Object error) {
    _completer!.completeError(error);
  }
}
