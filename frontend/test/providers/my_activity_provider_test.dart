import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/community_provider.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/models/my_community_activity.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/providers/my_activity_provider.dart';
import 'package:frontend/services/community_service.dart';

void main() {
  for (final more in [false, true]) {
    test(
      'removed post is not restored by older successful ${more ? "page" : "refresh"}',
      () async {
        final service = ControlledService();
        final accepted = <String>[];
        final notifier = MyActivityNotifier(
          service,
          MyActivityType.written,
          reconcile: (item, _) {
            accepted.add(item.post.id);
            return item;
          },
        );
        addTearDown(notifier.dispose);
        var task = notifier.refresh();
        service.requests
            .removeAt(0)
            .complete(MyActivityPage([item('1')], 'next'));
        await task;
        accepted.clear();
        task = more ? notifier.loadMore() : notifier.refresh();
        notifier.remove('1');
        service.requests
            .removeAt(0)
            .complete(MyActivityPage([item('1'), item('2')], null));
        await task;
        expect(notifier.state.items.map((i) => i.post.id), ['2']);
        expect(accepted, ['2']);
        expect(notifier.state.loading, isFalse);
        expect(notifier.state.loadingMore, isFalse);
        // A later authoritative read can include a re-liked item again.
        task = notifier.refresh();
        service.requests
            .removeAt(0)
            .complete(MyActivityPage([item('1')], null));
        await task;
        expect(notifier.state.items.single.post.id, '1');
      },
    );
  }
  test(
    'previous account pending unlike cannot overwrite next account activity',
    () async {
      final service = ControlledService()
        ..pendingLike = Completer<Map<String, dynamic>>();
      final auth = SwitchingAuth();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((_) => auth),
          communityServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final provider = myActivityProvider(MyActivityType.liked);
      container.listen(provider, (_, _) {});
      final oldTask = container
          .read(communityProvider.notifier)
          .toggleLike('1');
      auth.switchTo('second');
      await container.pump();
      final newTask = container.read(provider.notifier).refresh();
      service.pendingLike!.complete({'liked': false, 'likesCount': 0});
      await oldTask;
      service.requests
          .removeAt(0)
          .complete(
            MyActivityPage([
              item(
                '1',
              ).withPost(item('1').post.copyWith(liked: true, likesCount: 1)),
            ], null),
          );
      await newTask;
      expect(container.read(provider).items.single.post.liked, isTrue);
    },
  );
  test(
    'account change recreates activity state and rejects old account response',
    () async {
      final service = ControlledService();
      final auth = SwitchingAuth();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((_) => auth),
          communityServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final provider = myActivityProvider(MyActivityType.written);
      container.listen(provider, (_, _) {});
      final oldTask = container.read(provider.notifier).refresh();
      final oldResponse = service.requests.removeAt(0);
      auth.switchTo('second');
      await container.pump();
      expect(container.read(provider).items, isEmpty);
      final newTask = container.read(provider.notifier).refresh();
      service.requests
          .removeAt(0)
          .complete(MyActivityPage([item('second-post')], null));
      await newTask;
      oldResponse.complete(MyActivityPage([item('first-secret')], null));
      await oldTask;
      expect(container.read(provider).items.single.post.id, 'second-post');
      expect(
        container.read(communityProvider).postsById.containsKey('first-secret'),
        isFalse,
      );
      auth.switchTo(null);
      await container.pump();
      expect(container.read(provider).items, isEmpty);
    },
  );

  test(
    'like completed during refresh is reconciled before accepting old response',
    () async {
      final service = ControlledService();
      final community = CommunityNotifier(service);
      addTearDown(community.dispose);
      final notifier = MyActivityNotifier(
        service,
        MyActivityType.liked,
        revision: () => community.mutationRevision,
        reconcile: (i, revision) =>
            i.withPost(community.acceptActivityPost(i.post, revision)),
      );
      addTearDown(notifier.dispose);
      final original = item(
        '1',
      ).withPost(item('1').post.copyWith(liked: true, likesCount: 1));
      var task = notifier.refresh();
      service.requests.removeAt(0).complete(MyActivityPage([original], null));
      await task;
      task = notifier.refresh();
      await community.toggleLike('1');
      service.requests.removeAt(0).complete(MyActivityPage([original], null));
      await task;
      expect(notifier.state.items, isEmpty);
      expect(community.state.postsById['1']!.liked, isFalse);
    },
  );
  test(
    'refresh failure does not restore an item removed while awaiting response',
    () async {
      final service = ControlledService();
      final notifier = MyActivityNotifier(service, MyActivityType.written);
      addTearDown(notifier.dispose);
      var task = notifier.refresh();
      service.requests.removeAt(0).complete(MyActivityPage([item('1')], null));
      await task;
      task = notifier.refresh();
      notifier.remove('1');
      service.requests.removeAt(0).completeError(StateError('offline'));
      await task;
      expect(notifier.state.items, isEmpty);
    },
  );
  test('refresh failure preserves loaded items and cursor', () async {
    final service = ControlledService();
    final notifier = MyActivityNotifier(service, MyActivityType.written);
    addTearDown(notifier.dispose);
    final initial = notifier.refresh();
    service.requests.removeAt(0).complete(MyActivityPage([item('1')], 'next'));
    await initial;
    final refresh = notifier.refresh();
    service.requests.removeAt(0).completeError(StateError('offline'));
    await refresh;
    expect(notifier.state.items.single.post.id, '1');
    expect(notifier.state.cursor, 'next');
    expect(notifier.state.error, isNotNull);
  });

  test('load more deduplicates and ignores late page after refresh', () async {
    final service = ControlledService();
    final notifier = MyActivityNotifier(service, MyActivityType.written);
    addTearDown(notifier.dispose);
    var task = notifier.refresh();
    service.requests.removeAt(0).complete(MyActivityPage([item('1')], 'a'));
    await task;
    task = notifier.loadMore();
    service.requests
        .removeAt(0)
        .complete(MyActivityPage([item('1'), item('2')], 'b'));
    await task;
    expect(notifier.state.items.length, 2);
    final more = notifier.loadMore();
    final late = service.requests.removeAt(0);
    final refresh = notifier.refresh();
    service.requests.removeAt(0).complete(MyActivityPage([item('3')], null));
    await refresh;
    late.complete(MyActivityPage([item('4')], null));
    await more;
    expect(notifier.state.items.single.post.id, '3');
  });

  test(
    'disposal rejects previous account response without reconciling cache',
    () async {
      final service = ControlledService();
      var reconciled = false;
      final notifier = MyActivityNotifier(
        service,
        MyActivityType.written,
        reconcile: (item, _) {
          reconciled = true;
          return item;
        },
      );
      final task = notifier.refresh();
      notifier.dispose();
      service.requests
          .removeAt(0)
          .complete(MyActivityPage([item('secret')], null));
      await task;
      expect(reconciled, isFalse);
    },
  );

  test('preserve depth follows cursor and atomically replaces list', () async {
    final service = ControlledService();
    final notifier = MyActivityNotifier(service, MyActivityType.commented);
    addTearDown(notifier.dispose);
    var task = notifier.refresh();
    service.requests
        .removeAt(0)
        .complete(MyActivityPage([item('1'), item('2')], null));
    await task;
    task = notifier.refresh(preserveDepth: true);
    service.requests
        .removeAt(0)
        .complete(MyActivityPage([item('new')], 'next'));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.items.length, 2);
    service.requests.removeAt(0).complete(MyActivityPage([item('old')], null));
    await task;
    expect(notifier.state.items.map((i) => i.post.id), ['new', 'old']);
  });

  test(
    'more failure can retry; duplicate in-flight calls are ignored',
    () async {
      final service = ControlledService();
      final notifier = MyActivityNotifier(service, MyActivityType.written);
      addTearDown(notifier.dispose);
      var task = notifier.refresh();
      service.requests
          .removeAt(0)
          .complete(MyActivityPage([item('1')], 'next'));
      await task;
      task = notifier.loadMore();
      await notifier.loadMore();
      expect(service.requests.length, 1);
      service.requests.removeAt(0).completeError(StateError('offline'));
      await task;
      expect(notifier.state.moreFailed, isTrue);
      task = notifier.loadMore();
      service.requests.removeAt(0).complete(MyActivityPage([item('2')], null));
      await task;
      expect(notifier.state.items.length, 2);
      expect(notifier.state.error, isNull);
    },
  );
}

MyCommunityActivity item(String id) => MyCommunityActivity(
  activityAt: '2026-09-10T12:00:00',
  post: Post(
    id: id,
    userId: 'me',
    authorNickname: 'me',
    content: 'body',
    category: 'FREE',
    likesCount: 0,
    liked: false,
    commentsCount: 0,
    imageUrls: [],
    createdAt: '2026-09-10T12:00:00',
  ),
);

class ControlledService extends CommunityService {
  Completer<Map<String, dynamic>>? pendingLike;
  @override
  Future<PostFeed> getFeed({
    String? category,
    CommunityFeedSort sort = CommunityFeedSort.latest,
    String? cursor,
    int limit = 20,
    String? keyword,
  }) async => const PostFeed(items: []);
  @override
  Future<Map<String, dynamic>> toggleLike(String postId) async =>
      pendingLike == null
      ? {'liked': false, 'likesCount': 0}
      : await pendingLike!.future;
  final requests = <Completer<MyActivityPage>>[];
  @override
  Future<MyActivityPage> getMyActivities(
    MyActivityType type, {
    String? cursor,
  }) {
    final request = Completer<MyActivityPage>();
    requests.add(request);
    return request.future;
  }
}

class SwitchingAuth extends AuthNotifier {
  SwitchingAuth()
    : super.test(
        const AuthState(
          isLoading: false,
          isAuthenticated: true,
          profile: UserProfile(
            id: 'first',
            email: 'first@example.com',
            nickname: 'first',
          ),
        ),
      );
  void switchTo(String? id) {
    state = AuthState(
      isLoading: false,
      isAuthenticated: id != null,
      profile: id == null
          ? null
          : UserProfile(id: id, email: '$id@example.com', nickname: id),
    );
  }
}
