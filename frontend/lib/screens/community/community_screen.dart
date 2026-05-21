import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../providers/community_provider.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';
import 'post_card.dart';

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
      appBar: AppBar(
        title: const AppText('커뮤니티', fontWeight: FontWeight.bold),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
      ),
      body: const _CommunityMainBody(),
      floatingActionButton: FloatingActionButton(
        key: const Key('community-write-fab'),
        backgroundColor: AppColors.primary,
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
      appBar: AppBar(
        title: AppText(
          kCommunityCategoryLabels[widget.initialCategory.toUpperCase()] ??
              '커뮤니티',
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: _CategoryTabs(),
        ),
      ),
      body: const _FeedList(key: Key('community-category-feed')),
      floatingActionButton: FloatingActionButton(
        key: const Key('community-write-fab'),
        backgroundColor: AppColors.primary,
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
    return CustomScrollView(
      slivers: const [
        SliverToBoxAdapter(child: _CategoryCarousel()),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: AppText('인기글', fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: true,
          child: _FeedList(key: Key('community-main-popular-feed')),
        ),
      ],
    );
  }
}

class _CategoryCarousel extends StatelessWidget {
  const _CategoryCarousel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('community-category-carousel'),
      height: 188,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final viewport = MediaQuery.sizeOf(context).width;
              final boxWidth = viewport > 390 ? 350.0 : viewport - 56;
              final tileWidth = (boxWidth - 32) / 5;
              return Container(
                width: boxWidth,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: kCommunityCategories
                      .map(
                        (category) => SizedBox(
                          width: tileWidth,
                          height: 64,
                          child: _CategoryTile(category: category),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
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
    return InkWell(
      key: Key('community-category-tile-$category'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/community/category/$category'),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: AppText(
            kCommunityCategoryLabels[category] ?? category,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemBuilder: (context, index) {
          final tab = kCommunityFeedTabs[index];
          final tabKey = tab == 'POPULAR'
              ? 'popular'
              : tab == 'ALL'
              ? 'all'
              : tab;
          final isActive = activeKey == tabKey;
          return ChoiceChip(
            key: Key('community-tab-$tab'),
            selected: isActive,
            label: AppText(
              kCommunityCategoryLabels[tab] ?? tab,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? AppColors.white : AppColors.text,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            onSelected: (_) =>
                ref.read(communityProvider.notifier).setFeedKey(tab),
          );
        },
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemCount: kCommunityFeedTabs.length,
      ),
    );
  }
}

class _FeedList extends ConsumerWidget {
  const _FeedList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityProvider);
    final posts = state.activePosts;

    if (posts.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return const Center(child: AppText('게시글이 없습니다', color: AppColors.muted));
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(communityProvider.notifier).loadFeed(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200) {
            ref.read(communityProvider.notifier).loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: posts.length + (state.nextCursor != null ? 1 : 0),
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
              onLike: () =>
                  ref.read(communityProvider.notifier).toggleLike(post.id),
            );
          },
        ),
      ),
    );
  }
}
