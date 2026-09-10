import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../models/my_community_activity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/my_activity_provider.dart';
import '../../widgets/app_header.dart';
import '../community/community_constants.dart';
import '../community/community_routes.dart';
import '../community/post_card.dart';

class MyActivityScreen extends ConsumerWidget {
  const MyActivityScreen({super.key, this.initialTab = 'written'});
  final String initialTab;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(
      authProvider.select((s) => s.isAuthenticated ? s.profile?.id : null),
    );
    return _ActivityTabs(
      key: ValueKey(account),
      initialType: MyActivityType.parse(initialTab),
    );
  }
}

class _ActivityTabs extends StatefulWidget {
  const _ActivityTabs({super.key, required this.initialType});
  final MyActivityType initialType;
  @override
  State<_ActivityTabs> createState() => _ActivityTabsState();
}

class _ActivityTabsState extends State<_ActivityTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialType.index,
  );
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.white,
    appBar: AppHeader(
      title: '나의 활동',
      showBackButton: true,
      centerTitle: true,
      onBack: () => context.canPop() ? context.pop() : context.go('/my'),
    ),
    body: Column(
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            for (final type in MyActivityType.values) Tab(text: type.label),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final type in MyActivityType.values)
                _ActivityList(type: type),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActivityList extends ConsumerStatefulWidget {
  const _ActivityList({required this.type});
  final MyActivityType type;
  @override
  ConsumerState<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends ConsumerState<_ActivityList>
    with AutomaticKeepAliveClientMixin {
  // Keep-alive preserves tab offsets; do not restore another account's offset
  // from the enclosing route's PageStorage after this widget is recreated.
  final _scroll = ScrollController(keepScrollOffset: false);
  final _keys = <String, GlobalKey>{};
  bool _opening = false;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(myActivityProvider(widget.type).notifier).ensureLoaded();
      }
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        final state = ref.read(myActivityProvider(widget.type));
        if (!state.moreFailed) {
          ref.read(myActivityProvider(widget.type).notifier).loadMore();
        }
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool preserveDepth = false}) async {
    String? anchor;
    double? y;
    for (final item in ref.read(myActivityProvider(widget.type)).items) {
      final box = _keys[item.post.id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached) {
        final top = box.localToGlobal(Offset.zero).dy;
        if (top >= 130) {
          anchor = item.post.id;
          y = top;
          break;
        }
      }
    }
    await ref
        .read(myActivityProvider(widget.type).notifier)
        .refresh(preserveDepth: preserveDepth);
    if (!mounted || anchor == null || y == null) return;
    final savedAnchor = anchor;
    final savedY = y;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box = _keys[savedAnchor]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached) {
        final offset =
            _scroll.offset + box.localToGlobal(Offset.zero).dy - savedY;
        _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
      }
    });
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _open(MyCommunityActivity item, {bool comment = false}) async {
    if (_opening) return;
    _opening = true;
    try {
      await ref.read(communityServiceProvider).getPost(item.post.id);
      if (!mounted) return;
      final path = comment
          ? Uri(
              path: '/community/posts/${item.post.id}/comments',
              queryParameters: {
                'thread': item.parentId ?? item.commentId!,
                'targetComment': item.commentId!,
              },
            ).toString()
          : '/community/posts/${item.post.id}';
      final result = await context.push<Object?>(path);
      if (!mounted) return;
      if (result == CommunityActivityResult.postUnavailable) {
        _removePost(item.post.id);
      } else if (result == CommunityActivityResult.openPost) {
        await ref.read(communityServiceProvider).getPost(item.post.id);
        if (!mounted) return;
        await context.push('/community/posts/${item.post.id}');
      }
      if (!mounted) return;
      await _refresh(preserveDepth: true);
      // Other visited tabs must also reflect edits, deletion and membership changes.
      for (final type in MyActivityType.values) {
        if (type != widget.type && ref.exists(myActivityProvider(type))) {
          await ref
              .read(myActivityProvider(type).notifier)
              .refresh(preserveDepth: true);
          if (!mounted) return;
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if ([403, 404].contains(e.response?.statusCode)) {
        _removePost(item.post.id);
        _message('삭제되었거나 볼 수 없는 게시글이에요.');
      } else {
        _message('게시글을 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } catch (_) {
      _message('게시글을 불러오지 못했어요. 다시 시도해 주세요.');
    } finally {
      _opening = false;
    }
  }

  void _removePost(String postId) {
    for (final type in MyActivityType.values) {
      if (ref.exists(myActivityProvider(type))) {
        ref.read(myActivityProvider(type).notifier).remove(postId);
      }
    }
  }

  Future<void> _like(MyCommunityActivity item) async {
    try {
      await ref.read(communityProvider.notifier).toggleLike(item.post.id);
      if (!mounted) return;
      if (ref.read(communityProvider).postsById[item.post.id]?.liked == false) {
        if (ref.exists(myActivityProvider(MyActivityType.liked))) {
          ref
              .read(myActivityProvider(MyActivityType.liked).notifier)
              .remove(item.post.id);
        }
      } else if (ref.exists(myActivityProvider(MyActivityType.liked))) {
        await ref
            .read(myActivityProvider(MyActivityType.liked).notifier)
            .refresh(preserveDepth: true);
      }
    } catch (_) {
      _message('공감을 변경하지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(myActivityProvider(widget.type));
    final community = ref.watch(communityProvider);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: PageStorageKey('my-activity-${widget.type.name}'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.loading) const LinearProgressIndicator(),
          if (state.error != null && !state.moreFailed)
            _retry(state.error!, () => _refresh(preserveDepth: true)),
          if (state.loaded && state.items.isEmpty && !state.loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
              child: Text(switch (widget.type) {
                MyActivityType.written => '아직 작성한 글이 없어요.',
                MyActivityType.liked => '아직 공감한 글이 없어요.',
                MyActivityType.commented => '아직 댓글을 남긴 글이 없어요.',
              }, textAlign: TextAlign.center),
            ),
          for (final item in state.items)
            Column(
              key: _keys.putIfAbsent(item.post.id, GlobalKey.new),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    '${widget.type.actionLabel} · ${formatCommunityRelativeTime(item.activityAt) ?? item.activityAt}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                PostCard(
                  post: community.postsById[item.post.id] ?? item.post,
                  onOpen: () => _open(item),
                  onLike: () => _like(item),
                  isLiking: community.isLiking(item.post.id),
                ),
                if (item.commentId != null)
                  TextButton(
                    onPressed: () => _open(item, comment: true),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(20),
                      foregroundColor: AppColors.text,
                    ),
                    child: Text(
                      '내 댓글 · ${item.commentContent}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          if (state.loadingMore)
            const Center(child: CircularProgressIndicator()),
          if (state.moreFailed)
            _retry(
              state.error!,
              () =>
                  ref.read(myActivityProvider(widget.type).notifier).loadMore(),
            ),
          if (state.cursor != null &&
              !state.loading &&
              !state.loadingMore &&
              !state.moreFailed)
            TextButton(
              onPressed: () =>
                  ref.read(myActivityProvider(widget.type).notifier).loadMore(),
              child: const Text('더보기'),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _retry(String message, VoidCallback retry) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(message),
        TextButton(onPressed: retry, child: const Text('다시 시도')),
      ],
    ),
  );
}
