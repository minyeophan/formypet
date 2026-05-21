import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../services/community_service.dart';

class CommunityState {
  final Map<String, List<Post>> postsByFeedKey;
  final Map<String, String?> cursorByFeedKey;
  final Map<String, bool> loadingByFeedKey;
  final String activeFeedKey;

  const CommunityState({
    required this.postsByFeedKey,
    required this.cursorByFeedKey,
    required this.loadingByFeedKey,
    required this.activeFeedKey,
  });

  List<Post> get activePosts => postsByFeedKey[activeFeedKey] ?? [];
  bool get isLoading => loadingByFeedKey[activeFeedKey] ?? false;
  String? get nextCursor => cursorByFeedKey[activeFeedKey];

  CommunityState copyWith({
    Map<String, List<Post>>? postsByFeedKey,
    Map<String, String?>? cursorByFeedKey,
    Map<String, bool>? loadingByFeedKey,
    String? activeFeedKey,
  }) => CommunityState(
    postsByFeedKey: postsByFeedKey ?? this.postsByFeedKey,
    cursorByFeedKey: cursorByFeedKey ?? this.cursorByFeedKey,
    loadingByFeedKey: loadingByFeedKey ?? this.loadingByFeedKey,
    activeFeedKey: activeFeedKey ?? this.activeFeedKey,
  );
}

class CommunityNotifier extends StateNotifier<CommunityState> {
  final CommunityService _svc;

  CommunityNotifier(this._svc)
    : super(
        const CommunityState(
          postsByFeedKey: {},
          cursorByFeedKey: {},
          loadingByFeedKey: {},
          activeFeedKey: 'popular',
        ),
      ) {
    loadFeed();
  }

  Future<void> setFeedKey(String feedKey) async {
    final key = _normalizeFeedKey(feedKey);
    state = state.copyWith(activeFeedKey: key);
    if ((state.postsByFeedKey[key] ?? []).isEmpty) {
      await loadFeed();
    }
  }

  Future<void> loadFeed({bool refresh = false}) async {
    final key = state.activeFeedKey;
    if (state.loadingByFeedKey[key] == true) return;

    final cursor = refresh ? null : state.cursorByFeedKey[key];
    final loading = Map<String, bool>.from(state.loadingByFeedKey);
    loading[key] = true;
    state = state.copyWith(loadingByFeedKey: loading);

    try {
      final feed = await _svc.getFeed(
        category: _categoryForKey(key),
        sort: _sortForKey(key),
        cursor: cursor,
      );
      final posts = Map<String, List<Post>>.from(state.postsByFeedKey);
      final cursors = Map<String, String?>.from(state.cursorByFeedKey);

      if (refresh) {
        posts[key] = feed.items;
      } else {
        posts[key] = [...(posts[key] ?? []), ...feed.items];
      }
      cursors[key] = feed.nextCursor;

      final done = Map<String, bool>.from(state.loadingByFeedKey);
      done[key] = false;
      state = state.copyWith(
        postsByFeedKey: posts,
        cursorByFeedKey: cursors,
        loadingByFeedKey: done,
      );
    } catch (_) {
      final done = Map<String, bool>.from(state.loadingByFeedKey);
      done[key] = false;
      state = state.copyWith(loadingByFeedKey: done);
    }
  }

  Future<void> loadMore() async {
    final key = state.activeFeedKey;
    if (state.cursorByFeedKey[key] == null) return;
    await loadFeed();
  }

  Future<void> toggleLike(String postId) async {
    final key = state.activeFeedKey;
    final result = await _svc.toggleLike(postId);
    final liked = result['liked'] as bool;
    final likesCount = result['likesCount'] as int;

    final posts = Map<String, List<Post>>.from(state.postsByFeedKey);
    posts[key] = (posts[key] ?? [])
        .map(
          (p) => p.id == postId
              ? p.copyWith(liked: liked, likesCount: likesCount)
              : p,
        )
        .toList();
    state = state.copyWith(postsByFeedKey: posts);
  }

  Future<Post> createPost({
    required String content,
    String? title,
    required String category,
    List<XFile> files = const [],
    PollDraft? poll,
  }) async {
    final post = await _svc.createPost(
      content: content,
      title: title,
      category: category,
      files: files,
      poll: poll,
    );
    final posts = Map<String, List<Post>>.from(state.postsByFeedKey);
    for (final key in {state.activeFeedKey, 'all', post.category}) {
      if (posts.containsKey(key)) {
        posts[key] = [post, ...(posts[key] ?? [])];
      }
    }
    state = state.copyWith(postsByFeedKey: posts);
    return post;
  }

  String _normalizeFeedKey(String feedKey) {
    final normalized = feedKey.toUpperCase();
    if (normalized == 'POPULAR') return 'popular';
    if (normalized == 'ALL') return 'all';
    return normalized;
  }

  String? _categoryForKey(String key) {
    if (key == 'popular' || key == 'all') return null;
    return key;
  }

  CommunityFeedSort _sortForKey(String key) =>
      key == 'popular' ? CommunityFeedSort.popular : CommunityFeedSort.latest;
}

final communityServiceProvider = Provider<CommunityService>(
  (_) => CommunityService(),
);

final communityProvider =
    StateNotifierProvider<CommunityNotifier, CommunityState>((ref) {
      return CommunityNotifier(ref.read(communityServiceProvider));
    });
