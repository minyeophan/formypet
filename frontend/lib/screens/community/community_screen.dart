import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/visuals/app_visual_id.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';
import 'community_constants.dart';
import 'community_routes.dart';
import 'post_card.dart';

const Color _communityTeal = Color(0xFF14B8A6);

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(communityProvider.notifier).setFeedKey('popular');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const _CommunityMainBody(),
      floatingActionButton: FloatingActionButton(
        key: const Key('community-write-fab'),
        shape: const CircleBorder(),
        backgroundColor: _communityTeal,
        foregroundColor: AppColors.white,
        onPressed: () => context.push('/community/write'),
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class CommunityCategoryScreen extends ConsumerStatefulWidget {
  final String initialCategory;

  const CommunityCategoryScreen({super.key, required this.initialCategory});

  @override
  ConsumerState<CommunityCategoryScreen> createState() =>
      _CommunityCategoryScreenState();
}

class _CommunityCategoryScreenState
    extends ConsumerState<CommunityCategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(communityProvider.notifier).setFeedKey(widget.initialCategory);
    });
  }

  @override
  void didUpdateWidget(covariant CommunityCategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(communityProvider.notifier).setFeedKey(widget.initialCategory);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const _CommunityCategoryBody(),
      floatingActionButton: FloatingActionButton(
        key: const Key('community-write-fab'),
        shape: const CircleBorder(),
        backgroundColor: _communityTeal,
        foregroundColor: AppColors.white,
        onPressed: () => context.push('/community/write'),
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class _CommunityMainBody extends StatelessWidget {
  const _CommunityMainBody();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: const [
          _CommunityHeader(),
          Expanded(child: _CommunityMainScroll()),
        ],
      ),
    );
  }
}

class _CommunityCategoryBody extends ConsumerWidget {
  const _CommunityCategoryBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeKey = ref.watch(communityProvider).activeFeedKey;
    return SafeArea(
      child: Stack(
        children: [
          const Positioned(
            right: 12,
            bottom: 8,
            child: Opacity(
              opacity: 0.06,
              child: AppVisual(id: AppVisualId.communityPaw, size: 72),
            ),
          ),
          Column(
            children: [
              const _CommunityHeader(showBack: true),
              Expanded(
                child: ColoredBox(
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      const _CategoryTabs(),
                      const _CategoryFilterRow(),
                      const _GuidePanel(),
                      Expanded(
                        child: _FeedList(
                          key: const Key('community-category-feed'),
                          feedKey: activeKey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  final bool showBack;

  const _CommunityHeader({this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('community-header'),
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Row(
        children: [
          SizedBox(
            key: const Key('community-header-leading-slot'),
            width: showBack ? 44 : 0,
            height: 44,
            child: showBack
                ? AppBackButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        context.pop();
                        return;
                      }
                      context.go('/community');
                    },
                  )
                : const SizedBox.shrink(),
          ),
          if (showBack) const SizedBox(width: 8),
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText(
                '커뮤니티',
                key: Key('community-header-title'),
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
          Row(
            key: const Key('community-header-actions'),
            mainAxisSize: MainAxisSize.min,
            children: [
              _CommunityHeaderButton(
                key: const Key('community-search-button'),
                icon: Icons.search_rounded,
                tooltip: '검색',
                onTap: () => _showCommunityToast(context, '준비중'),
              ),
              const SizedBox(width: 4),
              _CommunityHeaderButton(
                key: const Key('community-notification-button'),
                icon: Icons.notifications_none_rounded,
                tooltip: '알림',
                onTap: () => _showCommunityToast(context, '준비중'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunitySectionHeader extends StatelessWidget {
  const _CommunitySectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: AppText('지금 인기글', fontSize: 16, fontWeight: FontWeight.bold),
          ),
          AppText(
            'popular · 전체',
            fontSize: 11,
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}

class _CategoryCarousel extends StatefulWidget {
  const _CategoryCarousel();

  @override
  State<_CategoryCarousel> createState() => _CategoryCarouselState();
}

class _CategoryCarouselState extends State<_CategoryCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('community-category-carousel'),
      height: 204,
      child: Column(
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: _CategoryPanel(
                      index: 0,
                      entries: _communityPrimaryCategories,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: _CategoryPanel(
                      index: 1,
                      entries: _communitySecondaryCategories,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              2,
              (index) => AnimatedContainer(
                key: Key('community-category-page-dot-$index'),
                duration: const Duration(milliseconds: 180),
                width: _page == index ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _page == index ? _communityTeal : AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  final int index;
  final List<String> entries;

  const _CategoryPanel({required this.index, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('community-category-panel-$index'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            Row(
              children: [
                for (var column = 0; column < 5; column++) ...[
                  Expanded(
                    child: SizedBox(
                      height: 72,
                      child: row * 5 + column < entries.length
                          ? _CategoryTile(category: entries[row * 5 + column])
                          : const SizedBox.shrink(),
                    ),
                  ),
                  if (column != 4) const SizedBox(width: 8),
                ],
              ],
            ),
            if (row != 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final accent = _communityAccentFor(category);
    final iconSize = MediaQuery.sizeOf(context).width < 360 ? 44.0 : 48.0;
    return InkWell(
      key: Key('community-category-tile-$category'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/community/category/$category'),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: Center(
                child: AppVisual(
                  id: communityVisualId(category),
                  color: accent,
                  size: 21,
                ),
              ),
            ),
            const SizedBox(height: 5),
            AppText(
              kCommunityCategoryLabels[category] ?? category,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends ConsumerWidget {
  const _CategoryTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeKey = ref.watch(communityProvider).activeFeedKey;
    return SizedBox(
      key: const Key('community-category-tabs'),
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        itemBuilder: (context, index) {
          final tab = kCommunityFeedTabs[index];
          final tabKey = tab == 'POPULAR'
              ? 'popular'
              : tab == 'ALL'
              ? 'all'
              : tab;
          final isActive = activeKey == tabKey;
          return InkWell(
            key: Key('community-tab-$tab'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(communityProvider.notifier).setFeedKey(tab),
            child: Container(
              padding: const EdgeInsets.fromLTRB(3, 8, 3, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? AppColors.text : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: AppText(
                kCommunityCategoryLabels[tab] ?? tab,
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.text : AppColors.textSecondary,
              ),
            ),
          );
        },
        separatorBuilder: (_, index) => const SizedBox(width: 20),
        itemCount: kCommunityFeedTabs.length,
      ),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Container(
            key: const Key('community-filter-pill'),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const AppText(
              '전체⌄',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('community-guide-panel'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFAF8),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.muted),
          SizedBox(width: 8),
          Expanded(
            child: AppText(
              '커뮤니티 이용 가이드',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppDisclosureChevron(size: 20),
        ],
      ),
    );
  }
}

class _CommunityMainScroll extends ConsumerWidget {
  const _CommunityMainScroll();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const feedKey = 'popular';
    final state = ref.watch(communityProvider);
    final posts = state.postsForFeed(feedKey);
    return RefreshIndicator(
      onRefresh: () => ref
          .read(communityProvider.notifier)
          .loadFeed(feedKey: feedKey, refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            _handlePagination(notification, ref, feedKey, state, posts),
        child: CustomScrollView(
          key: const Key('community-main-popular-feed'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 672),
                  child: _CategoryCarousel(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 672),
                  child: _CommunitySectionHeader(),
                ),
              ),
            ),
            ..._feedSlivers(context, ref, feedKey, state, posts, isMain: true),
            const SliverToBoxAdapter(child: SizedBox(height: 92)),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends ConsumerWidget {
  final String feedKey;

  const _FeedList({super.key, required this.feedKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityProvider);
    final posts = state.postsForFeed(feedKey);
    return RefreshIndicator(
      onRefresh: () => ref
          .read(communityProvider.notifier)
          .loadFeed(feedKey: feedKey, refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          return _handlePagination(notification, ref, feedKey, state, posts);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 92),
          children: _feedBoxChildren(
            context,
            ref,
            feedKey,
            state,
            posts,
            isMain: false,
          ),
        ),
      ),
    );
  }
}

bool _handlePagination(
  ScrollNotification notification,
  WidgetRef ref,
  String feedKey,
  CommunityState state,
  List posts,
) {
  if (notification.depth != 0 ||
      notification.metrics.axis != Axis.vertical ||
      posts.isEmpty ||
      notification.metrics.extentAfter >= 200 ||
      state.nextCursorForFeed(feedKey) == null ||
      state.isLoadingFeed(feedKey)) {
    return false;
  }
  ref.read(communityProvider.notifier).loadMore(feedKey: feedKey);
  return false;
}

List<Widget> _feedBoxChildren(
  BuildContext context,
  WidgetRef ref,
  String feedKey,
  CommunityState state,
  List posts, {
  required bool isMain,
}) {
  final failure = state.failureForFeed(feedKey);
  final children = <Widget>[];
  if (posts.isEmpty && state.isLoadingFeed(feedKey)) {
    return List.generate(
      3,
      (index) => _FeedWidth(child: _FeedSkeleton(index: index)),
    );
  }
  if (posts.isEmpty &&
      failure?.requestKind == CommunityFeedRequestKind.initial) {
    return [
      _FeedWidth(
        child: _FeedMessage(
          key: const Key('community-feed-error'),
          message: isMain ? '인기글을 불러오지 못했어요' : '게시글을 불러오지 못했어요',
          retry: () =>
              ref.read(communityProvider.notifier).loadFeed(feedKey: feedKey),
        ),
      ),
    ];
  }
  if (posts.isEmpty) {
    return [
      _FeedWidth(
        child: _FeedMessage(
          key: const Key('community-feed-empty'),
          message: isMain ? '아직 인기글이 없어요' : '이 카테고리에는 아직 게시글이 없어요',
        ),
      ),
    ];
  }
  if (failure?.requestKind == CommunityFeedRequestKind.refresh) {
    children.add(
      _FeedWidth(
        child: _FeedMessage(
          key: const Key('community-feed-refresh-error'),
          message: isMain ? '인기글을 새로고침하지 못했어요' : '게시글을 새로고침하지 못했어요',
          retry: () => ref
              .read(communityProvider.notifier)
              .loadFeed(feedKey: feedKey, refresh: true),
        ),
      ),
    );
  }
  for (final post in posts.cast<dynamic>()) {
    children.add(
      _FeedWidth(
        child: PostCard(
          post: post,
          isLiking: state.isLiking(post.id),
          onOpen: () => context.push(communityPostPath(post.id, feedKey)),
          onLike: () async {
            try {
              await ref
                  .read(communityProvider.notifier)
                  .toggleLike(post.id, feedKey: feedKey);
            } catch (_) {
              if (context.mounted) {
                _showCommunityToast(context, '좋아요를 반영하지 못했어요');
              }
            }
          },
        ),
      ),
    );
  }
  if (state.isLoadingMoreFeed(feedKey)) {
    children.add(
      const Padding(
        key: Key('community-feed-load-more-progress'),
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  } else if (failure?.requestKind == CommunityFeedRequestKind.loadMore) {
    children.add(
      _FeedWidth(
        child: _FeedMessage(
          key: const Key('community-feed-load-more-retry'),
          message: isMain ? '인기글을 더 불러오지 못했어요' : '게시글을 더 불러오지 못했어요',
          retry: () =>
              ref.read(communityProvider.notifier).loadMore(feedKey: feedKey),
        ),
      ),
    );
  }
  return children;
}

List<Widget> _feedSlivers(
  BuildContext context,
  WidgetRef ref,
  String feedKey,
  CommunityState state,
  List posts, {
  required bool isMain,
}) => [
  SliverList(
    delegate: SliverChildListDelegate(
      _feedBoxChildren(context, ref, feedKey, state, posts, isMain: isMain),
    ),
  ),
];

class _FeedSkeleton extends StatelessWidget {
  final int index;
  const _FeedSkeleton({required this.index});
  @override
  Widget build(BuildContext context) => Container(
    key: Key('community-feed-skeleton-$index'),
    height: 142,
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(18),
    ),
  );
}

class _FeedMessage extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const _FeedMessage({super.key, required this.message, this.retry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        AppText(message, color: AppColors.muted, textAlign: TextAlign.center),
        if (retry != null) ...[
          const SizedBox(height: 10),
          TextButton(
            key: const Key('community-feed-retry'),
            onPressed: retry,
            child: const Text('다시 시도'),
          ),
        ],
      ],
    ),
  );
}

class _FeedWidth extends StatelessWidget {
  final Widget child;
  const _FeedWidth({required this.child});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: child,
    ),
  );
}

const List<String> _communityPrimaryCategories = [
  'ALL',
  'POPULAR',
  'CARE',
  'FOOD',
  'OUTING',
  'SHOW',
  'QUESTION',
  'FREE',
  'ADOPTION',
  'RESCUE',
];

const List<String> _communitySecondaryCategories = ['NEWS', 'EVENT'];

Color _communityAccentFor(String category) => switch (category) {
  'POPULAR' || 'FOOD' || 'RESCUE' => const Color(0xFFFF8A65),
  'CARE' || 'FREE' => const Color(0xFF81C784),
  'OUTING' || 'QUESTION' || 'NEWS' => const Color(0xFF64B5F6),
  'SHOW' || 'ADOPTION' || 'EVENT' => const Color(0xFFBA68C8),
  _ => AppColors.textSecondary,
};

void _showCommunityToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Center(
          widthFactor: 1,
          child: AppText(
            message,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        width: 112,
        elevation: 0,
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        duration: const Duration(milliseconds: 1200),
      ),
    );
}

class _CommunityHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CommunityHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    ),
  );
}
