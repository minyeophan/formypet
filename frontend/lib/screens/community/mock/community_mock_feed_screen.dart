import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../models/post.dart';
import '../../../widgets/app_text.dart';
import 'community_mock_provider.dart';

class CommunityMockFeedScreen extends ConsumerWidget {
  const CommunityMockFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mockCommunityProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppText('커뮤니티 목업', fontWeight: FontWeight.w700),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
      ),
      body: ListView.separated(
        key: const Key('mock-feed-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: state.posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = state.posts[index];
          return MockCommunityPostCard(
            post: post,
            commentsCount: state.commentsCountFor(post.id),
            onOpen: () => context.push('/community/mock/posts/${post.id}'),
            onToggleLike: () =>
                ref.read(mockCommunityProvider.notifier).toggleLike(post.id),
          );
        },
      ),
    );
  }
}

class MockCommunityPostCard extends StatelessWidget {
  final Post post;
  final int commentsCount;
  final VoidCallback onOpen;
  final VoidCallback onToggleLike;

  const MockCommunityPostCard({
    super.key,
    required this.post,
    required this.commentsCount,
    required this.onOpen,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('mock-post-card-${post.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                post.authorNickname,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 7),
              if (post.title != null)
                AppText(post.title!, fontSize: 16, fontWeight: FontWeight.w700),
              const SizedBox(height: 6),
              AppText(
                post.content,
                fontSize: 13,
                color: AppColors.textSecondary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    key: Key('mock-post-like-${post.id}'),
                    onPressed: onToggleLike,
                    icon: Icon(
                      post.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: post.liked
                          ? Colors.redAccent
                          : AppColors.textSecondary,
                      size: 19,
                    ),
                  ),
                  AppText('좋아요 ${post.likesCount}', fontSize: 12),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  const SizedBox(width: 5),
                  AppText('댓글 $commentsCount', fontSize: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
