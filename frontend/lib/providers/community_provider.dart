import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../services/community_service.dart';
import '../screens/community/community_constants.dart';

enum CommunityFeedRequestKind { initial, refresh, loadMore }

class CommunityFeedFailure {
  final CommunityFeedRequestKind requestKind;
  final Object error;

  const CommunityFeedFailure({required this.requestKind, required this.error});
}

class CommunityState {
  final Map<String, List<Post>> postsByFeedKey;
  final Map<String, String?> cursorByFeedKey;
  final Map<String, CommunityFeedRequestKind> requestKindByFeedKey;
  final Map<String, CommunityFeedFailure> failureByFeedKey;
  final Set<String> likingPostIds;
  final Map<String, Post> postsById;
  final String activeFeedKey;

  const CommunityState({
    required this.postsByFeedKey,
    required this.cursorByFeedKey,
    required this.requestKindByFeedKey,
    required this.failureByFeedKey,
    required this.likingPostIds,
    required this.postsById,
    required this.activeFeedKey,
  });

  List<Post> postsForFeed(String feedKey) =>
      postsByFeedKey[normalizeCommunityFeedKey(feedKey)] ?? [];
  CommunityFeedRequestKind? requestKindForFeed(String feedKey) =>
      requestKindByFeedKey[normalizeCommunityFeedKey(feedKey)];
  bool isLoadingFeed(String feedKey) => requestKindForFeed(feedKey) != null;
  bool isRefreshingFeed(String feedKey) =>
      requestKindForFeed(feedKey) == CommunityFeedRequestKind.refresh;
  bool isLoadingMoreFeed(String feedKey) =>
      requestKindForFeed(feedKey) == CommunityFeedRequestKind.loadMore;
  CommunityFeedFailure? failureForFeed(String feedKey) =>
      failureByFeedKey[normalizeCommunityFeedKey(feedKey)];
  bool isLiking(String postId) => likingPostIds.contains(postId);
  String? nextCursorForFeed(String feedKey) =>
      cursorByFeedKey[normalizeCommunityFeedKey(feedKey)];

  List<Post> get activePosts => postsForFeed(activeFeedKey);
  bool get isLoading => isLoadingFeed(activeFeedKey);
  String? get nextCursor => nextCursorForFeed(activeFeedKey);

  CommunityState copyWith({
    Map<String, List<Post>>? postsByFeedKey,
    Map<String, String?>? cursorByFeedKey,
    Map<String, CommunityFeedRequestKind>? requestKindByFeedKey,
    Map<String, CommunityFeedFailure>? failureByFeedKey,
    Set<String>? likingPostIds,
    Map<String, Post>? postsById,
    String? activeFeedKey,
  }) => CommunityState(
    postsByFeedKey: postsByFeedKey ?? this.postsByFeedKey,
    cursorByFeedKey: cursorByFeedKey ?? this.cursorByFeedKey,
    requestKindByFeedKey: requestKindByFeedKey ?? this.requestKindByFeedKey,
    failureByFeedKey: failureByFeedKey ?? this.failureByFeedKey,
    likingPostIds: likingPostIds ?? this.likingPostIds,
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
          requestKindByFeedKey: {},
          failureByFeedKey: {},
          likingPostIds: {},
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
    if (state.isLoadingFeed(key)) return;

    final hasPosts = state.postsForFeed(key).isNotEmpty;
    final kind = refresh && hasPosts
        ? CommunityFeedRequestKind.refresh
        : CommunityFeedRequestKind.initial;
    await _requestFeed(key, kind);
  }

  Future<void> _requestFeed(String key, CommunityFeedRequestKind kind) async {
    if (state.isLoadingFeed(key)) return;
    final requests = Map<String, CommunityFeedRequestKind>.from(
      state.requestKindByFeedKey,
    )..[key] = kind;
    final failures = Map<String, CommunityFeedFailure>.from(
      state.failureByFeedKey,
    )..remove(key);
    state = state.copyWith(
      requestKindByFeedKey: requests,
      failureByFeedKey: failures,
    );

    final cursor = kind == CommunityFeedRequestKind.loadMore
        ? state.cursorByFeedKey[key]
        : null;

    try {
      final feed = await _svc.getFeed(
        category: _categoryForKey(key),
        sort: _sortForKey(key),
        cursor: cursor,
      );
      final posts = Map<String, List<Post>>.from(state.postsByFeedKey);
      final cursors = Map<String, String?>.from(state.cursorByFeedKey);

      if (kind != CommunityFeedRequestKind.loadMore) {
        posts[key] = feed.items;
      } else {
        final merged = [...(posts[key] ?? []), ...feed.items];
        posts[key] = [
          for (final id in merged.map((post) => post.id).toSet())
            merged.firstWhere((post) => post.id == id),
        ];
      }
      final postCache = Map<String, Post>.from(state.postsById);
      for (final post in feed.items) {
        postCache[post.id] = post;
      }
      cursors[key] = feed.nextCursor;

      final done = Map<String, CommunityFeedRequestKind>.from(
        state.requestKindByFeedKey,
      )..remove(key);
      state = state.copyWith(
        postsByFeedKey: posts,
        cursorByFeedKey: cursors,
        requestKindByFeedKey: done,
        postsById: postCache,
      );
    } catch (error) {
      final done = Map<String, CommunityFeedRequestKind>.from(
        state.requestKindByFeedKey,
      )..remove(key);
      final failures = Map<String, CommunityFeedFailure>.from(
        state.failureByFeedKey,
      )..[key] = CommunityFeedFailure(requestKind: kind, error: error);
      state = state.copyWith(
        requestKindByFeedKey: done,
        failureByFeedKey: failures,
      );
    }
  }

  Future<void> loadMore({String? feedKey}) async {
    final key = normalizeCommunityFeedKey(feedKey ?? state.activeFeedKey);
    if (state.cursorByFeedKey[key] == null) return;
    await _requestFeed(key, CommunityFeedRequestKind.loadMore);
  }

  Future<void> toggleLike(String postId, {String? feedKey}) async {
    if (state.isLiking(postId)) return;
    state = state.copyWith(likingPostIds: {...state.likingPostIds, postId});
    try {
      final result = await _svc.toggleLike(postId);
      final post = state.postsById[postId];
      if (post != null) {
        _replacePost(
          post.copyWith(
            liked: result['liked'] as bool,
            likesCount: result['likesCount'] as int,
          ),
        );
      }
    } finally {
      state = state.copyWith(
        likingPostIds: {...state.likingPostIds}..remove(postId),
      );
    }
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

  Future<PostComment> createComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    final comment = await _svc.createComment(
      postId,
      content,
      parentCommentId: parentCommentId,
    );
    final post = state.postsById[postId];
    if (post != null) {
      _replacePost(post.copyWith(commentsCount: comment.commentsCount));
    }
    return comment;
  }

  Future<PostComment> updateComment(
    String postId,
    String commentId,
    String content,
  ) {
    return _svc.updateComment(postId, commentId, content);
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _svc.deleteComment(postId, commentId);
    final post = state.postsById[postId];
    if (post != null) {
      _replacePost(post.copyWith(commentsCount: max(0, post.commentsCount - 1)));
    }
  }

  Future<Post> createPost({
    required String content,
    required String title,
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
  final normalized = normalizeCommunitySourceKey(feedKey);
  return normalized.isEmpty ? feedKey.toUpperCase() : normalized;
}

final communityServiceProvider = Provider<CommunityService>(
  (_) => CommunityService(),
);

final communityProvider =
    StateNotifierProvider<CommunityNotifier, CommunityState>((ref) {
      return CommunityNotifier(ref.read(communityServiceProvider));
    });
