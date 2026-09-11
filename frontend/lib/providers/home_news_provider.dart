import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../services/community_service.dart';
import 'community_provider.dart';
import 'auth_provider.dart';

class HomeNewsState {
  final List<Post> posts;
  final bool isInitialLoading;
  final bool isRefreshing;
  final Object? initialError;

  const HomeNewsState({
    this.posts = const [],
    this.isInitialLoading = true,
    this.isRefreshing = false,
    this.initialError,
  });

  HomeNewsState copyWith({
    List<Post>? posts,
    bool? isInitialLoading,
    bool? isRefreshing,
    Object? initialError,
    bool clearInitialError = false,
  }) => HomeNewsState(
    posts: posts ?? this.posts,
    isInitialLoading: isInitialLoading ?? this.isInitialLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    initialError: clearInitialError
        ? null
        : (initialError ?? this.initialError),
  );
}

class HomeNewsNotifier extends StateNotifier<HomeNewsState> {
  HomeNewsNotifier(this._service) : super(const HomeNewsState());

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
        category: 'NEWS',
        sort: CommunityFeedSort.latest,
        limit: 3,
      );
      if (!mounted) return;
      state = HomeNewsState(
        posts: feed.items
            .where((post) => post.category == 'NEWS')
            .take(3)
            .toList(),
        isInitialLoading: false,
      );
    } catch (error) {
      if (!mounted) return;
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

final homeNewsProvider =
    StateNotifierProvider.autoDispose<HomeNewsNotifier, HomeNewsState>((ref) {
      ref.watch(
        authProvider.select(
          (state) => state.isAuthenticated ? state.profile?.id : null,
        ),
      );
      final notifier = HomeNewsNotifier(ref.watch(communityServiceProvider));
      unawaited(notifier.load().catchError((_) {}));
      return notifier;
    });
