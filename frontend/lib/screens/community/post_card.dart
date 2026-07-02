import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/date_utils.dart';
import '../../models/post.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/app_visual.dart';
import '../../core/visuals/app_visual_id.dart';
import 'community_constants.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final Future<void> Function() onLike;
  final bool isLiking;
  final VoidCallback? onOpen;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    this.isLiking = false,
    this.onOpen,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final title = post.title?.trim() ?? '';
    final content = post.content.trim();
    final hasTitle = title.isNotEmpty;
    final headline = hasTitle ? title : (content.isEmpty ? '내용 없음' : content);
    final preview = hasTitle ? content : '';
    final author = post.authorNickname.trim().isEmpty
        ? '익명집사'
        : post.authorNickname.trim();
    final relativeTime = _formatPostRelativeTime(post.createdAt);
    return Card(
      key: ValueKey('community-post-card-${post.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: AppColors.surface.withValues(alpha: 0.92),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: _isFocused ? AppColors.textSecondary : AppColors.border,
          width: _isFocused ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onOpen,
        onFocusChange: (isFocused) {
          if (_isFocused == isFocused) return;
          setState(() => _isFocused = isFocused);
        },
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: AppColors.text.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Badge(
                    label:
                        kCommunityCategoryLabels[post.category] ??
                        post.category,
                  ),
                  if (post.poll != null) ...[
                    const SizedBox(width: 6),
                    const _Badge(
                      key: Key('community-post-poll-badge'),
                      label: '투표',
                    ),
                  ],
                  const Spacer(),
                  if (relativeTime != null)
                    AppText(relativeTime, fontSize: 11, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          headline,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: AppColors.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    _PostThumbnail(
                      key: ValueKey('community-post-image-${post.id}'),
                      url: post.imageUrls.first,
                      count: post.imageUrls.length,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ClipOval(
                    child: AuthenticatedNetworkImage(
                      key: ValueKey('community-author-avatar-${post.id}'),
                      url: post.authorProfileImageUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      fallback: const ColoredBox(
                        color: AppColors.surfaceSoft,
                        child: Center(
                          child: AppVisual(
                            id: AppVisualId.communityPaw,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      author,
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
                      Semantics(
                        label: widget.isLiking ? '좋아요 처리 중' : '좋아요',
                        button: true,
                        enabled: !widget.isLiking,
                        child: InkWell(
                          key: ValueKey('community-like-button-${post.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: widget.isLiking
                              ? null
                              : () async => widget.onLike(),
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
                                  color: post.liked
                                      ? Colors.red
                                      : AppColors.muted,
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

  const _PostThumbnail({super.key, required this.url, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('community-post-thumbnail'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AuthenticatedNetworkImage(
            url: url,
            width: 96,
            height: 96,
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

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surfaceSoft,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(999),
    ),
    child: AppText(
      label,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
    ),
  );
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
