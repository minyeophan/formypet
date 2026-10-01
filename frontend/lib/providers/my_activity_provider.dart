import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/my_community_activity.dart';
import '../services/community_service.dart';
import 'auth_provider.dart';
import 'community_provider.dart';

final myActivityProvider = StateNotifierProvider.autoDispose
    .family<MyActivityNotifier, MyActivityState, MyActivityType>((ref, type) {
      final account = ref.watch(
        authProvider.select((s) => s.isAuthenticated ? s.profile?.id : null),
      );
      final community = ref.watch(communityProvider.notifier);
      return MyActivityNotifier(
        ref.read(communityServiceProvider),
        type,
        enabled: account != null,
        revision: () => community.mutationRevision,
        reconcile: (item, revision) =>
            item.withPost(community.acceptActivityPost(item.post, revision)),
      );
    });

class MyActivityState {
  final List<MyCommunityActivity> items;
  final String? cursor;
  final bool loaded, loading, loadingMore;
  final String? error;
  final bool moreFailed;
  const MyActivityState({
    this.items = const [],
    this.cursor,
    this.loaded = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.moreFailed = false,
  });
}

class MyActivityNotifier extends StateNotifier<MyActivityState> {
  final CommunityService service;
  final MyActivityType type;
  final bool enabled;
  final int Function() revision;
  final MyCommunityActivity Function(MyCommunityActivity, int) reconcile;
  int _generation = 0;
  int _removalRevision = 0;
  final Map<String, int> _removedAt = {};
  MyActivityNotifier(
    this.service,
    this.type, {
    this.enabled = true,
    int Function()? revision,
    MyCommunityActivity Function(MyCommunityActivity, int)? reconcile,
  }) : revision = revision ?? (() => 0),
       reconcile = reconcile ?? ((item, _) => item),
       super(const MyActivityState());

  Future<void> ensureLoaded() async {
    if (!state.loaded && !state.loading) await refresh();
  }

  Future<void> refresh({bool preserveDepth = false}) async {
    if (!enabled) return;
    final generation = ++_generation;
    final requestRevision = revision();
    final requestRemovalRevision = _removalRevision;
    final previous = state;
    final target = preserveDepth ? previous.items.length : 0;
    state = MyActivityState(
      items: previous.items,
      cursor: previous.cursor,
      loaded: previous.loaded,
      loading: true,
    );
    try {
      final items = <String, MyCommunityActivity>{};
      String? cursor;
      final cursors = <String>{};
      do {
        final page = await service.getMyActivities(type, cursor: cursor);
        if (!mounted || generation != _generation) return;
        for (final item in page.items) {
          items[item.post.id] = item;
        }
        cursor = page.nextCursor;
      } while (cursor != null && items.length < target && cursors.add(cursor));
      final resolved = items.values
          .where((i) => (_removedAt[i.post.id] ?? 0) <= requestRemovalRevision)
          .map((i) => reconcile(i, requestRevision))
          .where((i) => type != MyActivityType.liked || i.post.liked)
          .toList();
      state = MyActivityState(items: resolved, cursor: cursor, loaded: true);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      state = MyActivityState(
        items: state.items,
        cursor: previous.cursor,
        loaded: previous.loaded,
        error: '활동을 불러오지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  Future<void> loadMore() async {
    if (!enabled ||
        state.loading ||
        state.loadingMore ||
        state.cursor == null) {
      return;
    }
    final generation = _generation;
    final requestRevision = revision();
    final requestRemovalRevision = _removalRevision;
    final previous = state;
    state = MyActivityState(
      items: previous.items,
      cursor: previous.cursor,
      loaded: true,
      loadingMore: true,
    );
    try {
      final page = await service.getMyActivities(type, cursor: previous.cursor);
      if (!mounted || generation != _generation) return;
      final items = {for (final i in state.items) i.post.id: i};
      for (final raw in page.items) {
        if ((_removedAt[raw.post.id] ?? 0) > requestRemovalRevision) continue;
        final i = reconcile(raw, requestRevision);
        if (type != MyActivityType.liked || i.post.liked) items[i.post.id] = i;
      }
      state = MyActivityState(
        items: items.values.toList(),
        loaded: true,
        cursor: page.nextCursor == previous.cursor ? null : page.nextCursor,
      );
    } catch (_) {
      if (!mounted || generation != _generation) return;
      state = MyActivityState(
        items: state.items,
        cursor: previous.cursor,
        loaded: true,
        moreFailed: true,
        error: '추가 목록을 불러오지 못했어요.',
      );
    }
  }

  void remove(String postId) {
    // Reject older responses before they reach the shared post cache. A new
    // request remains authoritative, so a later re-like can include this ID.
    _removedAt[postId] = ++_removalRevision;
    state = MyActivityState(
      items: state.items.where((i) => i.post.id != postId).toList(),
      cursor: state.cursor,
      loaded: state.loaded,
      loading: state.loading,
      loadingMore: state.loadingMore,
      error: state.error,
      moreFailed: state.moreFailed,
    );
  }
}
