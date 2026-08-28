import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/services/community_service.dart';

void main() {
  test('tracks initial request and failure per feed', () async {
    final service = _ControlledService();
    final notifier = CommunityNotifier(service);

    expect(
      notifier.state.requestKindForFeed('popular'),
      CommunityFeedRequestKind.initial,
    );
    service.requests.single.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.isLoadingFeed('popular'), isFalse);
    expect(
      notifier.state.failureForFeed('popular')?.requestKind,
      CommunityFeedRequestKind.initial,
    );
    expect(notifier.state.failureForFeed('all'), isNull);
  });

  test('refresh failure preserves posts and cursor', () async {
    final service = _ControlledService();
    final notifier = CommunityNotifier(service);
    service.requests
        .removeAt(0)
        .complete(PostFeed(items: [_post('one')], nextCursor: 'next'));
    await Future<void>.delayed(Duration.zero);

    final refresh = notifier.loadFeed(feedKey: 'popular', refresh: true);
    expect(notifier.state.isRefreshingFeed('popular'), isTrue);
    service.requests.single.completeError(StateError('offline'));
    await refresh;

    expect(notifier.state.postsForFeed('popular').single.id, 'one');
    expect(notifier.state.nextCursorForFeed('popular'), 'next');
    expect(
      notifier.state.failureForFeed('popular')?.requestKind,
      CommunityFeedRequestKind.refresh,
    );
  });

  test('load more removes duplicate post ids', () async {
    final service = _ControlledService();
    final notifier = CommunityNotifier(service);
    service.requests
        .removeAt(0)
        .complete(PostFeed(items: [_post('one')], nextCursor: 'next'));
    await Future<void>.delayed(Duration.zero);

    final more = notifier.loadMore(feedKey: 'popular');
    expect(notifier.state.isLoadingMoreFeed('popular'), isTrue);
    service.requests.single.complete(
      PostFeed(items: [_post('one'), _post('two')], nextCursor: null),
    );
    await more;

    expect(notifier.state.postsForFeed('popular').map((post) => post.id), [
      'one',
      'two',
    ]);
  });

  test('like requests are locked and failure releases lock', () async {
    final service = _ControlledService();
    final notifier = CommunityNotifier(service);
    service.requests
        .removeAt(0)
        .complete(PostFeed(items: [_post('one')], nextCursor: null));
    await Future<void>.delayed(Duration.zero);

    final first = notifier.toggleLike('one');
    final second = notifier.toggleLike('one');
    expect(notifier.state.isLiking('one'), isTrue);
    expect(service.likeRequests, hasLength(1));
    service.likeRequests.single.completeError(StateError('offline'));
    await expectLater(first, throwsStateError);
    await second;

    expect(notifier.state.isLiking('one'), isFalse);
    expect(notifier.state.postsById['one']!.liked, isFalse);
  });

  test('comment update preserves cached post count', () async {
    final service = _ControlledService();
    final notifier = CommunityNotifier(service);
    service.requests.removeAt(0).complete(
      PostFeed(items: [_post('one', commentsCount: 2)], nextCursor: null),
    );
    await Future<void>.delayed(Duration.zero);

    final update = notifier.updateComment('one', 'c1', ' updated ');
    expect(service.commentUpdates.single, ('one', 'c1', ' updated '));
    service.commentUpdateResponses.single.complete(
      const PostComment(
        id: 'c1',
        userId: 'user',
        authorNickname: '집사',
        content: 'updated',
        createdAt: '2026-07-02T00:00:00Z',
        commentsCount: 2,
      ),
    );

    final updated = await update;

    expect(updated.content, 'updated');
    expect(notifier.state.postsById['one']!.commentsCount, 2);
  });

  test('comment delete decrements cached post count without going below zero', () async {
    final service = _ControlledService();
    final notifier = CommunityNotifier(service);
    service.requests.removeAt(0).complete(
      PostFeed(items: [_post('one', commentsCount: 1)], nextCursor: null),
    );
    await Future<void>.delayed(Duration.zero);

    final first = notifier.deleteComment('one', 'c1');
    expect(service.commentDeletes.single, ('one', 'c1'));
    service.commentDeleteResponses.single.complete();
    await first;

    expect(notifier.state.postsById['one']!.commentsCount, 0);

    final second = notifier.deleteComment('one', 'c2');
    service.commentDeleteResponses.last.complete();
    await second;

    expect(notifier.state.postsById['one']!.commentsCount, 0);
  });

  test('post update replaces cache and delete removes it from feeds', () async {
    final service = _ControlledService();
    final notifier = CommunityNotifier(service);
    service.requests.removeAt(0).complete(
      PostFeed(items: [_post('one')], nextCursor: null),
    );
    await Future<void>.delayed(Duration.zero);

    final update = notifier.updatePost('one', title: 'updated', content: 'body', category: 'FREE');
    service.postUpdateResponse.complete(_post('one'));
    await update;
    expect(notifier.state.postsById.containsKey('one'), isTrue);

    final deletion = notifier.deletePost('one');
    service.postDeleteResponse.complete();
    await deletion;
    expect(notifier.state.postsById.containsKey('one'), isFalse);
    expect(notifier.state.postsForFeed('popular'), isEmpty);
  });
}

Post _post(String id, {int commentsCount = 0}) => Post(
  id: id,
  userId: 'user',
  authorNickname: '집사',
  content: id,
  category: 'FREE',
  likesCount: 0,
  liked: false,
  commentsCount: commentsCount,
  imageUrls: const [],
  createdAt: '2026-07-02T00:00:00Z',
);

class _ControlledService extends CommunityService {
  final List<Completer<PostFeed>> requests = [];
  final List<Completer<Map<String, dynamic>>> likeRequests = [];
  final List<(String postId, String commentId, String content)> commentUpdates =
      [];
  final List<Completer<PostComment>> commentUpdateResponses = [];
  final List<(String postId, String commentId)> commentDeletes = [];
  final List<Completer<void>> commentDeleteResponses = [];
  final postUpdateResponse = Completer<Post>();
  final postDeleteResponse = Completer<void>();

  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) {
    final completer = Completer<PostFeed>();
    requests.add(completer);
    return completer.future;
  }

  @override
  Future<Map<String, dynamic>> toggleLike(String postId) {
    final completer = Completer<Map<String, dynamic>>();
    likeRequests.add(completer);
    return completer.future;
  }

  @override
  Future<PostComment> updateComment(
    String postId,
    String commentId,
    String content,
  ) {
    final completer = Completer<PostComment>();
    commentUpdates.add((postId, commentId, content));
    commentUpdateResponses.add(completer);
    return completer.future;
  }

  @override
  Future<void> deleteComment(String postId, String commentId) {
    final completer = Completer<void>();
    commentDeletes.add((postId, commentId));
    commentDeleteResponses.add(completer);
    return completer.future;
  }

  @override
  Future<Post> updatePost(String postId, {required String title, required String content, required String category, String? petSpecies}) => postUpdateResponse.future;

  @override
  Future<void> deletePost(String postId) => postDeleteResponse.future;
}
