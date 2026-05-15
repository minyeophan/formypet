import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/community_provider.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';
import 'post_card.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityProvider);
    final posts = state.activePosts;

    return Scaffold(
      appBar: AppBar(
        title: const AppText('커뮤니티', fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/community/write'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _CategoryBar(activeCategory: state.activeCategory),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(communityProvider.notifier).loadFeed(refresh: true),
        child: posts.isEmpty && state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : posts.isEmpty
                ? const Center(child: AppText('게시글이 없습니다', color: Colors.grey))
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollEndNotification &&
                          n.metrics.extentAfter < 200) {
                        ref.read(communityProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount:
                          posts.length + (state.nextCursor != null ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == posts.length) {
                          return const Center(
                              child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ));
                        }
                        return PostCard(
                          post: posts[i],
                          onLike: () => ref
                              .read(communityProvider.notifier)
                              .toggleLike(posts[i].id),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _CategoryBar extends ConsumerWidget {
  final String activeCategory;
  const _CategoryBar({required this.activeCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const labels = {
      'all': '전체',
      'popular': '인기',
      'dog': '강아지',
      'cat': '고양이',
      'rabbit': '토끼',
      'hamster': '햄스터',
      'bird': '새',
      'other': '기타',
    };
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: kCommunityCategories.map((cat) {
          final isActive = cat == activeCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(communityProvider.notifier).setCategory(cat),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AppText(
                  labels[cat] ?? cat,
                  color: isActive ? Colors.white : Colors.black87,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
