import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/my_community_activity.dart';
import 'package:frontend/models/notification.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/blocked_users_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/providers/content_visibility_provider.dart';
import 'package:frontend/providers/home_popular_posts_provider.dart';
import 'package:frontend/providers/my_activity_provider.dart';
import 'package:frontend/providers/notification_provider.dart';
import 'package:frontend/services/community_safety_service.dart';
import 'package:frontend/services/community_service.dart';
import 'package:frontend/services/notification_service.dart';

class _Auth extends AuthNotifier {
  _Auth() : super.test(_session('viewer'));
  static AuthState _session(String id) => AuthState(
    isAuthenticated: true,
    isLoading: false,
    profile: UserProfile(id: id, email: '$id@test.local', nickname: id),
  );
  void switchAccount(String id) => state = _session(id);
}

class _Community extends CommunityService {
  final feeds = <Completer<PostFeed>>[];
  final activities = <Completer<MyActivityPage>>[];
  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) {
    final request = Completer<PostFeed>();
    feeds.add(request);
    return request.future;
  }

  @override
  Future<MyActivityPage> getMyActivities(
    MyActivityType type, {
    String? cursor,
  }) {
    final request = Completer<MyActivityPage>();
    activities.add(request);
    return request.future;
  }
}

class _Notifications extends NotificationService {
  final requests = <Completer<NotificationFeed>>[];
  @override
  Future<NotificationFeed> list({String? cursor, int limit = 20}) {
    final request = Completer<NotificationFeed>();
    requests.add(request);
    return request.future;
  }
}

class _Blocks extends CommunitySafetyService {
  final requests = <Completer<List<BlockedUser>>>[];
  @override
  Future<List<BlockedUser>> getBlockedUsers() {
    final request = Completer<List<BlockedUser>>();
    requests.add(request);
    return request.future;
  }
}

Post _post(String id) => Post.fromJson({
  'id': id,
  'userId': 'author',
  'authorNickname': 'author',
  'title': id,
  'content': id,
  'category': 'FREE',
  'createdAt': '',
});

void main() {
  test(
    'visibility change retires feed/search/activity/home/blocks requests',
    () async {
      final service = _Community();
      final blocks = _Blocks();
      final auth = _Auth();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((_) => auth),
          communityServiceProvider.overrideWithValue(service),
          communitySafetyServiceProvider.overrideWithValue(blocks),
        ],
      );
      addTearDown(container.dispose);
      container.listen(communityProvider, (_, _) {});
      container.listen(homePopularPostsProvider, (_, _) {});
      container.listen(myActivityProvider(MyActivityType.commented), (_, _) {});
      container.listen(blockedUsersProvider, (_, _) {});
      container
          .read(myActivityProvider(MyActivityType.commented).notifier)
          .ensureLoaded();
      final old = container.read(communityProvider.notifier);
      final pendingSearch = old.searchPage('search');
      final oldFeeds = List.of(service.feeds);
      final oldActivity = service.activities.single;
      final oldBlocks = blocks.requests.single;

      container.read(contentVisibilityRevisionProvider.notifier).state++;
      await container.pump();
      container
          .read(myActivityProvider(MyActivityType.commented).notifier)
          .ensureLoaded();
      expect(container.read(communityProvider).postsById, isEmpty);
      expect(container.read(homePopularPostsProvider).posts, isEmpty);
      expect(
        container.read(myActivityProvider(MyActivityType.commented)).items,
        isEmpty,
      );
      expect(service.activities.length, 2);
      expect(blocks.requests.length, 2);

      for (final request in oldFeeds) {
        request.complete(PostFeed(items: [_post('blocked')]));
      }
      oldActivity.complete(
        MyActivityPage([
          MyCommunityActivity(post: _post('blocked'), activityAt: ''),
        ], null),
      );
      oldBlocks.complete([
        const BlockedUser(userId: 'stale', nickname: 'stale'),
      ]);
      expect((await pendingSearch).items, isEmpty);
      for (final request in service.feeds.skip(oldFeeds.length)) {
        request.complete(PostFeed(items: [_post('visible')]));
      }
      service.activities.last.complete(
        MyActivityPage([
          MyCommunityActivity(post: _post('visible'), activityAt: ''),
        ], null),
      );
      blocks.requests.last.complete([]);
      await container.pump();
      expect(container.read(communityProvider).postsById.keys, ['visible']);
      expect(
        container.read(homePopularPostsProvider).posts.single.id,
        'visible',
      );
      expect(
        container
            .read(myActivityProvider(MyActivityType.commented))
            .items
            .single
            .post
            .id,
        'visible',
      );
      expect(container.read(blockedUsersProvider).value, isEmpty);

      // An account transition retires the same cache generation.
      final refresh = container
          .read(communityProvider.notifier)
          .loadFeed(refresh: true);
      final previousAccountRequest = service.feeds.last;
      auth.switchAccount('other');
      await container.pump();
      previousAccountRequest.complete(
        PostFeed(items: [_post('previous-account')]),
      );
      await refresh;
      expect(container.read(communityProvider).postsById, isEmpty);
      expect(container.read(homePopularPostsProvider).posts, isEmpty);
    },
  );

  test(
    'block and unblock reset notifications and ignore old successes and errors',
    () async {
      final service = _Notifications();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((_) => _Auth()),
          notificationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(notificationProvider.notifier);
      final pending = notifier.loadFirstPage();
      container.read(contentVisibilityRevisionProvider.notifier).state++;
      expect(service.requests, hasLength(2));
      service.requests.first.complete(
        const NotificationFeed(
          items: [
            NotificationItem(
              id: 'blocked',
              type: 'COMMENT',
              title: 'old',
              body: 'old',
            ),
          ],
          hasMore: false,
          unreadCount: 1,
        ),
      );
      await pending;
      expect(notifier.state.items, isEmpty);
      service.requests.last.complete(
        const NotificationFeed(items: [], hasMore: false, unreadCount: 0),
      );
      await container.pump();
      final staleFailure = notifier.loadFirstPage();
      final oldRequest = service.requests.last;
      container.read(contentVisibilityRevisionProvider.notifier).state++;
      oldRequest.completeError(StateError('old request failed'));
      await staleFailure;
      expect(notifier.state.errorText, isNull);
      service.requests.last.complete(
        const NotificationFeed(items: [], hasMore: false, unreadCount: 0),
      );
      await container.pump();
      expect(notifier.state.unreadCount, 0);
    },
  );
}
