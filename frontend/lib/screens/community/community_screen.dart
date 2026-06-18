import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../providers/community_provider.dart';
import '../../services/community_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_text.dart';
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
          _CategoryCarousel(),
          _CommunitySectionHeader(),
          Expanded(
            child: _FeedList(
              key: Key('community-main-popular-feed'),
              feedKey: 'popular',
            ),
          ),
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
      child: Column(
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
              AppHeaderIconButton(
                key: const Key('community-notification-button'),
                icon: Icons.notifications_none_rounded,
                tooltip: '알림',
                onTap: () => _showCommunityToast(context, '준비중'),
              ),
              const SizedBox(width: 4),
              AppHeaderIconButton(
                key: const Key('community-search-button'),
                icon: Icons.search_rounded,
                tooltip: '검색',
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
  final ScrollController _controller = ScrollController();
  bool _isSnapping = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _snapToNearestPanel() async {
    if (!_controller.hasClients) return;
    if (_isSnapping) return;

    final position = _controller.position;
    final panelWidth = _communityCategoryPanelWidth(context);
    final nextPanelOffset = (panelWidth + 12).clamp(
      0.0,
      position.maxScrollExtent,
    );
    final target = position.pixels < nextPanelOffset / 2
        ? 0.0
        : nextPanelOffset;

    if ((position.pixels - target).abs() <= 0.5) return;

    _isSnapping = true;
    try {
      await position.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isSnapping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('community-category-carousel'),
      height: 184,
      child: Listener(
        onPointerUp: (_) => _snapToNearestPanel(),
        onPointerCancel: (_) => _snapToNearestPanel(),
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            if (notification.depth != 0) return false;
            _snapToNearestPanel();
            return true;
          },
          child: ListView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            children: const [
              _CategoryPanel(index: 0, entries: _communityPrimaryCategories),
              _CategoryPanel(index: 1, entries: _communitySecondaryCategories),
            ],
          ),
        ),
      ),
    );
  }
}

double _communityCategoryPanelWidth(BuildContext context) {
  final viewport = MediaQuery.sizeOf(context).width;
  return viewport > 390 ? 350.0 : viewport - 32;
}

class _CategoryPanel extends StatelessWidget {
  final int index;
  final List<String> entries;

  const _CategoryPanel({required this.index, required this.entries});

  @override
  Widget build(BuildContext context) {
    final panelWidth = _communityCategoryPanelWidth(context);
    return Container(
      key: Key('community-category-panel-$index'),
      width: panelWidth,
      margin: const EdgeInsets.only(right: 12),
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
                      height: 63,
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
            Icon(_communityIconFor(category), color: accent, size: 21),
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

class _FeedList extends ConsumerWidget {
  final String feedKey;

  const _FeedList({super.key, required this.feedKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityProvider);
    final posts = state.postsForFeed(feedKey);
    final isLoading = state.isLoadingFeed(feedKey);
    final nextCursor = state.nextCursorForFeed(feedKey);

    if (posts.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return const Center(child: AppText('게시글이 없습니다', color: AppColors.muted));
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(communityProvider.notifier)
          .loadFeed(feedKey: feedKey, refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200) {
            ref.read(communityProvider.notifier).loadMore(feedKey: feedKey);
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: posts.length + (nextCursor != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == posts.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final post = posts[index];
            return PostCard(
              post: post,
              onLike: () => ref
                  .read(communityProvider.notifier)
                  .toggleLike(post.id, feedKey: feedKey),
            );
          },
        ),
      ),
    );
  }
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

IconData _communityIconFor(String category) => switch (category) {
  'ALL' => Icons.grid_view_rounded,
  'POPULAR' => Icons.trending_up_rounded,
  'CARE' => Icons.health_and_safety_outlined,
  'FOOD' => Icons.restaurant_outlined,
  'OUTING' => Icons.directions_walk_rounded,
  'SHOW' => Icons.photo_camera_outlined,
  'QUESTION' => Icons.help_outline_rounded,
  'FREE' => Icons.chat_bubble_outline_rounded,
  'ADOPTION' => Icons.volunteer_activism_outlined,
  'RESCUE' => Icons.emergency_outlined,
  'NEWS' => Icons.article_outlined,
  'EVENT' => Icons.celebration_outlined,
  _ => Icons.grid_view_rounded,
};

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
