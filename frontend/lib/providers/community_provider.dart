import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../services/community_service.dart';

class CommunityState {
  // 8 categories, each with independent post list and cursor
  final Map<String, List<Post>> postsByCategory;
  final Map<String, String?> cursorByCategory;
  final Map<String, bool> loadingByCategory;
  final String activeCategory;

  const CommunityState({
    required this.postsByCategory,
    required this.cursorByCategory,
    required this.loadingByCategory,
    required this.activeCategory,
  });

  List<Post> get activePosts => postsByCategory[activeCategory] ?? [];
  bool get isLoading => loadingByCategory[activeCategory] ?? false;
  String? get nextCursor => cursorByCategory[activeCategory];

  CommunityState copyWith({
    Map<String, List<Post>>? postsByCategory,
    Map<String, String?>? cursorByCategory,
    Map<String, bool>? loadingByCategory,
    String? activeCategory,
  }) =>
      CommunityState(
        postsByCategory: postsByCategory ?? this.postsByCategory,
        cursorByCategory: cursorByCategory ?? this.cursorByCategory,
        loadingByCategory: loadingByCategory ?? this.loadingByCategory,
        activeCategory: activeCategory ?? this.activeCategory,
      );
}

class CommunityNotifier extends StateNotifier<CommunityState> {
  final CommunityService _svc;

  CommunityNotifier(this._svc)
      : super(CommunityState(
          postsByCategory: {},
          cursorByCategory: {},
          loadingByCategory: {},
          activeCategory: 'all',
        )) {
    loadFeed();
  }

  Future<void> setCategory(String category) async {
    state = state.copyWith(activeCategory: category);
    if ((state.postsByCategory[category] ?? []).isEmpty) {
      await loadFeed();
    }
  }

  Future<void> loadFeed({bool refresh = false}) async {
    final cat = state.activeCategory;
    if (state.loadingByCategory[cat] == true) return;

    final cursor = refresh ? null : state.cursorByCategory[cat];
    final loading = Map<String, bool>.from(state.loadingByCategory);
    loading[cat] = true;
    state = state.copyWith(loadingByCategory: loading);

    try {
      final feed = await _svc.getFeed(category: cat, cursor: cursor);
      final posts = Map<String, List<Post>>.from(state.postsByCategory);
      final cursors = Map<String, String?>.from(state.cursorByCategory);

      if (refresh) {
        posts[cat] = feed.items;
      } else {
        posts[cat] = [...(posts[cat] ?? []), ...feed.items];
      }
      cursors[cat] = feed.nextCursor;

      final done = Map<String, bool>.from(state.loadingByCategory);
      done[cat] = false;
      state = state.copyWith(
        postsByCategory: posts,
        cursorByCategory: cursors,
        loadingByCategory: done,
      );
    } catch (_) {
      final done = Map<String, bool>.from(state.loadingByCategory);
      done[cat] = false;
      state = state.copyWith(loadingByCategory: done);
    }
  }

  Future<void> loadMore() async {
    final cat = state.activeCategory;
    if (state.cursorByCategory[cat] == null) return;
    await loadFeed();
  }

  Future<void> toggleLike(String postId) async {
    final cat = state.activeCategory;
    final result = await _svc.toggleLike(postId);
    final liked = result['liked'] as bool;
    final likesCount = result['likesCount'] as int;

    final posts = Map<String, List<Post>>.from(state.postsByCategory);
    posts[cat] = (posts[cat] ?? [])
        .map((p) => p.id == postId
            ? p.copyWith(liked: liked, likesCount: likesCount)
            : p)
        .toList();
    state = state.copyWith(postsByCategory: posts);
  }

  Future<Post> createPost({
    required String content,
    String? title,
    required String category,
  }) async {
    final post = await _svc.createPost(
        content: content, title: title, category: category);
    // Prepend to active category and 'all'
    final posts = Map<String, List<Post>>.from(state.postsByCategory);
    for (final cat in [state.activeCategory, 'all']) {
      if (posts.containsKey(cat)) {
        posts[cat] = [post, ...(posts[cat] ?? [])];
      }
    }
    state = state.copyWith(postsByCategory: posts);
    return post;
  }
}

final communityServiceProvider =
    Provider<CommunityService>((_) => CommunityService());

final communityProvider =
    StateNotifierProvider<CommunityNotifier, CommunityState>((ref) {
  return CommunityNotifier(ref.read(communityServiceProvider));
});
