import '../../widgets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../core/app_interaction_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_v2_tokens.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_header.dart';
import 'community_routes.dart';
import 'post_card.dart';

class CommunitySearchScreen extends ConsumerStatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  ConsumerState<CommunitySearchScreen> createState() =>
      _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends ConsumerState<CommunitySearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController(keepScrollOffset: false);
  String? _nextCursor;
  bool _loadingMore = false;
  String? _moreError;
  List<Post> _posts = const [];
  int _searchGeneration = 0;
  bool _loading = false;
  String? _error;
  bool _searched = false;
  String? _lastKeyword;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      authProvider.select(
        (state) => state.isAuthenticated ? state.profile?.id : null,
      ),
      (_, _) => _clearSearch(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    ref.read(communityProvider.notifier).invalidateSearch();
    _controller.clear();
    setState(() {
      // Invalidate completions as well as cached results from the old account.
      _searchGeneration++;
      _loading = false;
      _posts = const [];
      _error = null;
      _searched = false;
      _lastKeyword = null;
      _nextCursor = null;
      _loadingMore = false;
      _moreError = null;
    });
  }

  Future<void> _search({String? retryKeyword}) async {
    final keyword = retryKeyword ?? _controller.text.trim();
    if (_loading && keyword == _lastKeyword) return;
    if (keyword.length < 2 || keyword.length > 20) {
      setState(() => _error = '검색어는 2~20자로 입력해 주세요.');
      return;
    }
    final generation = ++_searchGeneration;
    FocusScope.of(context).unfocus();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      _lastKeyword = keyword;
      _posts = const [];
      _nextCursor = null;
      _loadingMore = false;
      _moreError = null;
    });
    try {
      final page = await ref
          .read(communityProvider.notifier)
          .searchPage(keyword);
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _posts = {
            for (final post in page.items) post.id: post,
          }.values.toList();
          _nextCursor = page.nextCursor;
        });
      }
    } catch (_) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _error = '검색 결과를 불러오지 못했어요.');
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    final keyword = _lastKeyword;
    if (_loading || _loadingMore || cursor == null || keyword == null) return;
    final generation = _searchGeneration;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await ref
          .read(communityProvider.notifier)
          .searchPage(keyword, cursor: cursor);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _posts = {
          for (final post in _posts) post.id: post,
          for (final post in page.items) post.id: post,
        }.values.toList();
        _nextCursor = page.nextCursor == cursor ? null : page.nextCursor;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _moreError = '추가 결과를 불러오지 못했어요.');
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      await ref.read(communityProvider.notifier).toggleLike(postId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('좋아요를 변경하지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = ref.watch(communityProvider);
    return Scaffold(
      backgroundColor: AppV2Tokens.background,
      appBar: AppHeader(
        title: '커뮤니티 검색',
        showBackButton: true,
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              key: const Key('community-search-field'),
              controller: _controller,
              autofocus: true,
              cursorColor: AppV2Tokens.primary,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '게시글을 검색해 보세요',
                prefixIcon: const AppIcon(
                  Icons.search_rounded,
                  color: AppV2Tokens.primary,
                ),
                suffixIcon: IconButton(
                  tooltip: '검색어 지우기',
                  onPressed: _clearSearch,
                  icon: const AppIcon(Icons.close_rounded),
                ),
                filled: true,
                fillColor: AppInteractionStyle.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppV2Tokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppV2Tokens.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('community-search-submit-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppV2Tokens.primary,
                ).copyWith(overlayColor: AppInteractionStyle.overlay()),
                onPressed: _search,
                child: const Text('검색'),
              ),
            ),
          ),
          Expanded(child: _body(community)),
        ],
      ),
    );
  }

  Widget _body(CommunityState community) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('community-search-retry-button'),
              onPressed: _lastKeyword == null
                  ? null
                  : () => _search(retryKeyword: _lastKeyword),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    final posts = _posts
        .map((post) => community.postsById[post.id])
        .whereType<Post>()
        .toList();
    if (_searched && posts.isEmpty && _nextCursor == null) {
      return const Center(child: Text('검색 결과가 없어요.'));
    }
    if (!_searched) {
      return const Center(child: Text('궁금한 내용을 검색해 보세요.'));
    }
    return ListView.builder(
      key: const PageStorageKey('community-search-results'),
      controller: _scrollController,
      itemCount: posts.length + (_nextCursor == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_moreError != null) Text(_moreError!),
                TextButton(
                  key: const Key('community-search-load-more'),
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(
                    _loadingMore
                        ? '불러오는 중…'
                        : _moreError != null
                        ? '다시 시도'
                        : '더보기',
                  ),
                ),
              ],
            ),
          );
        }
        final post = posts[index];
        return PostCard(
          key: ValueKey(post.id),
          post: post,
          isLiking: community.isLiking(post.id),
          onLike: () => _toggleLike(post.id),
          onOpen: () => context.push(communityPostPath(post.id, 'search')),
        );
      },
    );
  }
}
