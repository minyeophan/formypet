import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/app_v2_tokens.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text.dart';
import '../../widgets/app_visual.dart';
import '../../widgets/preparing_toast.dart';
import 'community_constants.dart';
import 'community_routes.dart';
import 'post_card.dart';

const Color _communitySecondary = Color(0xFF6E5E0D);
const Color _communityError = Color(0xFFBA1A1A);

TextStyle _communityStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) => TextStyle(
  fontFamily: AppV2Tokens.fontFamily,
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
);

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
      backgroundColor: AppV2Tokens.background,
      body: const _CommunityMainBody(),
      floatingActionButton: FloatingActionButton(
        key: const Key('community-write-fab'),
        shape: const CircleBorder(),
        backgroundColor: AppV2Tokens.primary,
        foregroundColor: Colors.white,
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
  bool _activated = false;

  String get _routeFeedKey => normalizeCommunityFeedKey(widget.initialCategory);

  void _activateRouteFeed() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(communityProvider.notifier).setFeedKey(_routeFeedKey);
      if (mounted) setState(() => _activated = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _activateRouteFeed();
  }

  @override
  void didUpdateWidget(covariant CommunityCategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      _activated = false;
      _activateRouteFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppV2Tokens.background,
      body: _CommunityCategoryBody(
        routeFeedKey: _routeFeedKey,
        activated: _activated,
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('community-write-fab'),
        shape: const CircleBorder(),
        backgroundColor: AppV2Tokens.primary,
        foregroundColor: Colors.white,
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
  final String routeFeedKey;
  final bool activated;

  const _CommunityCategoryBody({
    required this.routeFeedKey,
    required this.activated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityProvider);
    final posts = state.postsForFeed(routeFeedKey);
    return SafeArea(
      child: Column(
        children: [
          const _CommunityHeader(showBack: true),
          Expanded(
            child: RefreshIndicator(
              color: AppV2Tokens.primary,
              onRefresh: () => ref
                  .read(communityProvider.notifier)
                  .loadFeed(feedKey: routeFeedKey, refresh: true),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) => _handlePagination(
                  notification,
                  ref,
                  routeFeedKey,
                  state,
                  posts,
                ),
                child: CustomScrollView(
                  key: const Key('community-category-feed'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _FeedWidth(
                        child: _CategoryTabs(routeFeedKey: routeFeedKey),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _FeedWidth(
                        child: _GuidePanel(key: ValueKey(routeFeedKey)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _FeedWidth(
                        child: const _CategorySectionHeader(),
                      ),
                    ),
                    if (!activated && posts.isEmpty)
                      SliverList(
                        delegate: SliverChildListDelegate(
                          List.generate(
                            3,
                            (index) =>
                                _FeedWidth(child: _FeedSkeleton(index: index)),
                          ),
                        ),
                      )
                    else
                      ..._feedSlivers(
                        context,
                        ref,
                        routeFeedKey,
                        state,
                        posts,
                        isMain: false,
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 92)),
                  ],
                ),
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
      decoration: const BoxDecoration(color: AppV2Tokens.background),
      child: AppHeader(
      title: '커뮤니티',
      titleKey: const Key('community-header-title'),
      leadingKey: const Key('community-header-leading-slot'),
      showBackButton: showBack,
      onBack: () {
        if (Navigator.of(context).canPop()) {
          context.pop();
          return;
        }
        context.go('/community');
      },
      leading: showBack
          ? null
          : const Icon(Icons.pets, size: 25, color: AppV2Tokens.primary),
      actions: [
        _CommunityHeaderButton(
          key: const Key('community-search-button'),
          icon: Icons.search_rounded,
          tooltip: '검색',
          onTap: () => showPreparingToast(context),
        ),
        _CommunityHeaderButton(
          key: const Key('community-notification-button'),
          icon: Icons.notifications_none_rounded,
          tooltip: '알림',
          onTap: () {
            final router = GoRouter.maybeOf(context);
            if (router == null) {
              showPreparingToast(context);
            } else {
              router.push('/notifications');
            }
          },
        ),
        const SizedBox(width: 12),
      ],
      ),
    );
  }
}

class _CommunitySectionHeader extends StatelessWidget {
  const _CommunitySectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '지금 인기글',
              style: _communityStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppV2Tokens.text,
              ),
            ),
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
                  color: _page == index
                      ? AppV2Tokens.primary
                      : AppV2Tokens.border,
                  borderRadius: BorderRadius.circular(12),
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
      color: Colors.transparent,
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
                  if (column != 4) const SizedBox(width: 4),
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
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/community/category/$category'),
      child: Ink(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppV2Tokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: AppVisual(
                    id: communityVisualId(category),
                    color: accent,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                kCommunityCategoryLabels[category] ?? category,
                style: _communityStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppV2Tokens.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatefulWidget {
  final String routeFeedKey;

  const _CategoryTabs({required this.routeFeedKey});

  @override
  State<_CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends State<_CategoryTabs> {
  late final List<GlobalKey> _chipKeys = List.generate(
    kCommunityFeedTabs.length,
    (_) => GlobalKey(),
  );

  void _revealActiveChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = kCommunityFeedTabs.indexWhere(
        (tab) => normalizeCommunityFeedKey(tab) == widget.routeFeedKey,
      );
      final context = index < 0 ? null : _chipKeys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _revealActiveChip();
  }

  @override
  void didUpdateWidget(covariant _CategoryTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeFeedKey != widget.routeFeedKey) _revealActiveChip();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('community-category-tabs'),
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        child: Row(
          children: List.generate(kCommunityFeedTabs.length, (index) {
            final tab = kCommunityFeedTabs[index];
            final tabKey = tab == 'POPULAR'
                ? 'popular'
                : tab == 'ALL'
                ? 'all'
                : tab;
            final isActive = widget.routeFeedKey == tabKey;
            return Padding(
              padding: EdgeInsets.only(
                right: index == kCommunityFeedTabs.length - 1 ? 0 : 8,
              ),
              child: Semantics(
                button: true,
                selected: isActive,
                child: InkWell(
                  key: Key('community-tab-$tab'),
                    borderRadius: BorderRadius.circular(12),
                  onTap: isActive
                      ? () {}
                      : () =>
                            context.pushReplacement('/community/category/$tab'),
                  child: Container(
                    key: _chipKeys[index],
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppV2Tokens.primary
                          : AppV2Tokens.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      kCommunityCategoryLabels[tab] ?? tab,
                      style: _communityStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : AppV2Tokens.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _GuidePanel extends StatefulWidget {
  const _GuidePanel({super.key});

  @override
  State<_GuidePanel> createState() => _GuidePanelState();
}

class _GuidePanelState extends State<_GuidePanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('community-guide-panel'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: AppV2Tokens.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Semantics(
        button: true,
        expanded: _expanded,
        child: InkWell(
          key: const Key('community-guide-toggle'),
          onTap: () => setState(() => _expanded = !_expanded),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppV2Tokens.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '커뮤니티 이용 가이드',
                        style: TextStyle(
                          fontFamily: AppV2Tokens.fontFamily,
                          fontSize: 16,
                          color: AppV2Tokens.text,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const AppDisclosureChevron(size: 20),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: _expanded
                      ? const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Column(
                            children: [
                              _GuideBullet('서로를 존중하는 따뜻한 언어 사용'),
                              _GuideBullet('건강 상담은 수의사 문의 권장'),
                              _GuideBullet('상업적 광고·홍보 제한'),
                              _GuideBullet('사진과 함께 일상 공유 권장'),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  final String text;
  const _GuideBullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•', style: TextStyle(color: AppV2Tokens.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: _communityStyle(
              fontSize: 14,
              color: AppV2Tokens.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '최신 게시글',
              style: _communityStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppV2Tokens.text,
              ),
            ),
          ),
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
      color: AppV2Tokens.primary,
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
  Widget build(BuildContext context) {
    final hasImage = index.isEven;
    return Container(
      key: Key('community-feed-skeleton-$index'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppV2Tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBar(width: 52, height: 20, radius: 999),
              const Spacer(),
              const _SkeletonBar(width: 42, height: 12),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBar(height: 20),
                    SizedBox(height: 7),
                    _SkeletonBar(width: 150, height: 20),
                  ],
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 16),
                const _SkeletonBar(
                  key: Key('community-skeleton-thumbnail'),
                  width: 80,
                  height: 80,
                  radius: 16,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _SkeletonBar(width: 32, height: 32, radius: 999),
              SizedBox(width: 8),
              _SkeletonBar(width: 72, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBar({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppV2Tokens.surfaceSoft,
      borderRadius: BorderRadius.circular(radius),
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
  'POPULAR' || 'FOOD' || 'QUESTION' || 'ADOPTION' => _communitySecondary,
  'RESCUE' => _communityError,
  _ => AppV2Tokens.textSecondary,
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
          color: AppV2Tokens.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppV2Tokens.surface,
                border: Border.all(color: AppV2Tokens.border),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppV2Tokens.textSecondary),
            ),
          ),
        ),
      ),
    ),
  );
}
