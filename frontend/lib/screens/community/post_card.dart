import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../models/post.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback? onOpen;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final title = post.title?.trim() ?? '';
    final content = post.content.trim();
    final hasTitle = title.isNotEmpty;
    final headline = hasTitle ? title : content;
    final preview = hasTitle ? content : '';
    final author = post.authorNickname.trim().isEmpty
        ? '익명집사'
        : post.authorNickname.trim();
    final relativeTime = _formatPostRelativeTime(post.createdAt);
    final metaParts = [
      author,
      if (relativeTime != null && relativeTime.isNotEmpty) relativeTime,
    ];

    return Card(
      key: ValueKey('community-post-card-${post.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: AppText(
                kCommunityCategoryLabels[post.category] ?? post.category,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (post.poll != null) ...[
                            Container(
                              key: const Key('community-post-poll-badge'),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F1FE),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const AppText('투표', fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64B5F6)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: AppText(
                              headline,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: AppColors.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        AppText(
                          preview,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (post.imageUrls.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _PostThumbnail(url: post.imageUrls.first, count: post.imageUrls.length),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppText(
                    metaParts.join(' · '),
                    fontSize: 12,
                    color: AppColors.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                          onTap: onLike,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              post.liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: post.liked ? Colors.red : AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            AppText(
                              '${post.likesCount}',
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    AppText(
                      '${post.commentsCount}',
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _PostThumbnail extends StatelessWidget {
  final String url;
  final int count;

  const _PostThumbnail({required this.url, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('community-post-thumbnail'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AuthenticatedNetworkImage(
            url: url,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            fallback: const ColoredBox(color: AppColors.surfaceSoft),
          ),
        ),
        if (count > 1)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              key: const Key('community-post-image-count'),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AppText('$count', fontSize: 10, color: AppColors.white),
            ),
          ),
      ],
    );
  }
}

String? _formatPostRelativeTime(String createdAt) {
  final trimmed = createdAt.trim();
  if (trimmed.isEmpty) return null;

  final created = DateTime.tryParse(trimmed);
  if (created == null) return null;

  final diff = DateTime.now().difference(created.toLocal());
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return formatDateShort(trimmed);
}
