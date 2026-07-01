import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../services/community_service.dart';
import 'community_provider.dart';

class HomePopularPostsState {
  final List<Post> posts;
  final bool isInitialLoading;
  final bool isRefreshing;
  final Object? initialError;

  const HomePopularPostsState({
    this.posts = const [],
    this.isInitialLoading = true,
    this.isRefreshing = false,
    this.initialError,
  });

  HomePopularPostsState copyWith({
    List<Post>? posts,
    bool? isInitialLoading,
    bool? isRefreshing,
    Object? initialError,
    bool clearInitialError = false,
  }) => HomePopularPostsState(
    posts: posts ?? this.posts,
    isInitialLoading: isInitialLoading ?? this.isInitialLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    initialError: clearInitialError
        ? null
        : (initialError ?? this.initialError),
  );
}

class HomePopularPostsNotifier extends StateNotifier<HomePopularPostsState> {
  HomePopularPostsNotifier(this._service)
    : super(const HomePopularPostsState());

  final CommunityService _service;
  Future<void>? _inFlight;

  Future<void> load() => _inFlight ??= _request(refreshing: false);

  Future<void> refresh() => _inFlight ??= _request(refreshing: true);

  Future<void> _request({required bool refreshing}) async {
    state = state.copyWith(
      isInitialLoading: !refreshing && state.posts.isEmpty,
      isRefreshing: refreshing,
      clearInitialError: true,
    );
    try {
      final feed = await _service.getFeed(
        sort: CommunityFeedSort.popular,
        limit: 3,
      );
      state = HomePopularPostsState(
        posts: feed.items.take(3).toList(),
        isInitialLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        isInitialLoading: false,
        isRefreshing: false,
        initialError: state.posts.isEmpty ? error : null,
      );
      rethrow;
    } finally {
      _inFlight = null;
    }
  }
}

final homePopularPostsProvider =
    StateNotifierProvider.autoDispose<
      HomePopularPostsNotifier,
      HomePopularPostsState
    >((ref) {
      final notifier = HomePopularPostsNotifier(
        ref.watch(communityServiceProvider),
      );
      unawaited(notifier.load().catchError((_) {}));
      return notifier;
    });
