import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../models/post.dart';
import '../../../widgets/app_text.dart';
import 'community_mock_provider.dart';

class CommunityPostHeader extends StatelessWidget {
  final Post post;

  const CommunityPostHeader({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.surfaceSoft,
          child: Text(
            post.authorNickname.isEmpty ? '?' : post.authorNickname[0],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(post.authorNickname, fontWeight: FontWeight.w700),
              AppText(
                post.createdAt.replaceFirst('T', ' '),
                fontSize: 11,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CommunityImageGallery extends StatelessWidget {
  final List<String> imageUrls;

  const CommunityImageGallery({super.key, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 240,
      child: Row(
        children: [
          for (var index = 0; index < imageUrls.length; index++) ...[
            Expanded(
              child: MockImagePlaceholder(
                key: Key('community-image-$index'),
                imageId: imageUrls[index],
                index: index + 1,
              ),
            ),
            if (index != imageUrls.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class MockImagePlaceholder extends StatelessWidget {
  final String imageId;
  final int index;

  const MockImagePlaceholder({
    super.key,
    required this.imageId,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (imageId) {
      'mock://photo-1/a' => const Color(0xFFFCE5CD),
      'mock://photo-1/b' => const Color(0xFFD9EAD3),
      _ => const Color(0xFFD9EAF7),
    };
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.pets_rounded, size: 72, color: AppColors.text),
          ),
          Positioned(
            right: 14,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AppText(
                '$index',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityPollCard extends StatelessWidget {
  final PostPoll poll;
  final ValueChanged<String> onVote;

  const CommunityPollCard({
    super.key,
    required this.poll,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll.options.fold<int>(
      0,
      (total, option) => total + option.votesCount,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(poll.question, fontWeight: FontWeight.w700),
          const SizedBox(height: 12),
          for (final option in poll.options) ...[
            InkWell(
              key: Key('mock-poll-option-${option.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onVote(option.id),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: option.votedByMe
                      ? const Color(0xFFFFE9D5)
                      : AppColors.surface,
                  border: Border.all(
                    color: option.votedByMe
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: AppText(option.text, fontSize: 13)),
                    AppText(
                      '${totalVotes == 0 ? 0 : (option.votesCount * 100 / totalVotes).round()}%',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ),
            if (option != poll.options.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class CommunityCommentsSection extends StatelessWidget {
  final List<MockCommunityComment> comments;

  const CommunityCommentsSection({super.key, required this.comments});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText('댓글 ${comments.length}', fontWeight: FontWeight.w700),
      const SizedBox(height: 12),
      if (comments.isEmpty)
        const AppText('첫 댓글을 남겨 주세요.', color: AppColors.muted)
      else
        for (final comment in comments)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(comment.authorNickname, fontWeight: FontWeight.w700),
                const SizedBox(height: 3),
                AppText(comment.content, fontSize: 13),
              ],
            ),
          ),
    ],
  );
}
