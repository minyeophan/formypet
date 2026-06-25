import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../services/community_service.dart';

class CommunityState {
  final Map<String, List<Post>> postsByFeedKey;
  final Map<String, String?> cursorByFeedKey;
  final Map<String, bool> loadingByFeedKey;
  final Map<String, Post> postsById;
  final String activeFeedKey;

  const CommunityState({
    required this.postsByFeedKey,
    required this.cursorByFeedKey,
    required this.loadingByFeedKey,
    required this.postsById,
    required this.activeFeedKey,
  });

  List<Post> postsForFeed(String feedKey) =>
      postsByFeedKey[normalizeCommunityFeedKey(feedKey)] ?? [];
  bool isLoadingFeed(String feedKey) =>
      loadingByFeedKey[normalizeCommunityFeedKey(feedKey)] ?? false;
  String? nextCursorForFeed(String feedKey) =>
      cursorByFeedKey[normalizeCommunityFeedKey(feedKey)];

  List<Post> get activePosts => postsForFeed(activeFeedKey);
  bool get isLoading => isLoadingFeed(activeFeedKey);
  String? get nextCursor => nextCursorForFeed(activeFeedKey);

  CommunityState copyWith({
    Map<String, List<Post>>? postsByFeedKey,
    Map<String, String?>? cursorByFeedKey,
    Map<String, bool>? loadingByFeedKey,
    Map<String, Post>? postsById,
    String? activeFeedKey,
  }) => CommunityState(
    postsByFeedKey: postsByFeedKey ?? this.postsByFeedKey,
    cursorByFeedKey: cursorByFeedKey ?? this.cursorByFeedKey,
    loadingByFeedKey: loadingByFeedKey ?? this.loadingByFeedKey,
    postsById: postsById ?? this.postsById,
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
          postsById: {},
          activeFeedKey: 'popular',
        ),
      ) {
    loadFeed();
  }

  Future<void> setFeedKey(String feedKey) async {
    final key = normalizeCommunityFeedKey(feedKey);
    state = state.copyWith(activeFeedKey: key);
    if ((state.postsByFeedKey[key] ?? []).isEmpty) {
      await loadFeed(feedKey: key);
    }
  }

  Future<void> loadFeed({String? feedKey, bool refresh = false}) async {
    final key = normalizeCommunityFeedKey(feedKey ?? state.activeFeedKey);
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
      final postCache = Map<String, Post>.from(state.postsById);
      for (final post in feed.items) {
        postCache[post.id] = post;
      }
      cursors[key] = feed.nextCursor;

      final done = Map<String, bool>.from(state.loadingByFeedKey);
      done[key] = false;
      state = state.copyWith(
        postsByFeedKey: posts,
        cursorByFeedKey: cursors,
        loadingByFeedKey: done,
        postsById: postCache,
      );
    } catch (_) {
      final done = Map<String, bool>.from(state.loadingByFeedKey);
      done[key] = false;
      state = state.copyWith(loadingByFeedKey: done);
    }
  }

  Future<void> loadMore({String? feedKey}) async {
    final key = normalizeCommunityFeedKey(feedKey ?? state.activeFeedKey);
    if (state.cursorByFeedKey[key] == null) return;
    await loadFeed(feedKey: key);
  }

  Future<void> toggleLike(String postId, {String? feedKey}) async {
    final result = await _svc.toggleLike(postId);
    final liked = result['liked'] as bool;
    final likesCount = result['likesCount'] as int;

    final post = state.postsById[postId];
    if (post == null) return;
    _replacePost(post.copyWith(liked: liked, likesCount: likesCount));
  }

  Future<Post> loadPost(String postId) async {
    final post = await _svc.getPost(postId);
    _replacePost(post);
    return post;
  }

  Future<Post> vote(String postId, String optionId) async {
    final post = await _svc.vote(postId, optionId);
    _replacePost(post);
    return post;
  }

  Future<PostComment> createComment(String postId, String content) async {
    final comment = await _svc.createComment(postId, content);
    final post = state.postsById[postId];
    if (post != null) {
      _replacePost(post.copyWith(commentsCount: comment.commentsCount));
    }
    return comment;
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
    final postCache = Map<String, Post>.from(state.postsById);
    postCache[post.id] = post;
    state = state.copyWith(postsById: postCache);
    return post;
  }

  void _replacePost(Post updated) {
    final posts = <String, List<Post>>{
      for (final entry in state.postsByFeedKey.entries)
        entry.key: entry.value
            .map((post) => post.id == updated.id ? updated : post)
            .toList(),
    };
    final postCache = Map<String, Post>.from(state.postsById);
    postCache[updated.id] = updated;
    state = state.copyWith(postsByFeedKey: posts, postsById: postCache);
  }

  String? _categoryForKey(String key) {
    if (key == 'popular' || key == 'all') return null;
    return key;
  }

  CommunityFeedSort _sortForKey(String key) =>
      key == 'popular' ? CommunityFeedSort.popular : CommunityFeedSort.latest;
}

String normalizeCommunityFeedKey(String feedKey) {
  final normalized = feedKey.toUpperCase();
  if (normalized == 'POPULAR') return 'popular';
  if (normalized == 'ALL') return 'all';
  return normalized;
}

final communityServiceProvider = Provider<CommunityService>(
  (_) => CommunityService(),
);

final communityProvider =
    StateNotifierProvider<CommunityNotifier, CommunityState>((ref) {
      return CommunityNotifier(ref.read(communityServiceProvider));
    });
