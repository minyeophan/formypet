import 'package:flutter/material.dart';

import '../../core/app_v2_tokens.dart';
import '../../models/post.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/app_category_badge.dart';
import 'community_constants.dart';

const _communityError = AppV2Tokens.error;

TextStyle _communityTextStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) => TextStyle(
  fontFamily: AppV2Tokens.fontFamily,
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
);

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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final title = post.title?.trim() ?? '';
    final headline = title.isEmpty ? '제목 없음' : title;
    final author = post.authorNickname.trim().isEmpty
        ? '익명집사'
        : post.authorNickname.trim();
    final relativeTime = formatCommunityRelativeTime(post.createdAt);
    final border = _isFocused
        ? Border.all(color: AppV2Tokens.primary, width: 2)
        : const Border(bottom: BorderSide(color: AppV2Tokens.border));

    return Material(
      key: ValueKey('community-post-card-${post.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpen,
        onHover: (isHovered) {
          if (_isHovered != isHovered) setState(() => _isHovered = isHovered);
        },
        onFocusChange: (isFocused) {
          if (_isFocused != isFocused) setState(() => _isFocused = isFocused);
        },
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: AppV2Tokens.primary.withValues(alpha: 0.10),
        child: DecoratedBox(
          decoration: BoxDecoration(border: border),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCategoryBadge(label: kCommunityCategoryLabels[post.category] ?? post.category),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.poll != null) ...[
                      const Text('투표', style: TextStyle(color: AppV2Tokens.primary, fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        headline,
                        style: _communityTextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _isHovered ? AppV2Tokens.primary : AppV2Tokens.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(post.content.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: _communityTextStyle(fontSize: 14, color: AppV2Tokens.textSecondary)),
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
                const SizedBox(height: 10),
                Row(
                  key: const Key('community-post-meta'),
                  children: [
                    Expanded(
                      child: Text(
                        '${author}${relativeTime == null ? '' : ' · $relativeTime'}',
                        style: _communityTextStyle(fontSize: 13, color: AppV2Tokens.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                          padding: const EdgeInsets.all(4),
                          child: _PostStat(
                            icon: post.liked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            count: post.likesCount,
                            color: post.liked
                                ? _communityError
                                : AppV2Tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _PostStat(
                      icon: Icons.chat_bubble_outline,
                      count: post.commentsCount,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostStat extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _PostStat({
    required this.icon,
    required this.count,
    this.color = AppV2Tokens.textSecondary,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 4),
      Text(
        '$count',
        style: _communityTextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppV2Tokens.textSecondary,
        ),
      ),
    ],
  );
}

class _PostThumbnail extends StatelessWidget {
  final String url;
  final int count;

  const _PostThumbnail({super.key, required this.url, required this.count});

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('community-post-thumbnail'),
    width: 80,
    height: 80,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AuthenticatedNetworkImage(
            url: url,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            fallback: const ColoredBox(color: AppV2Tokens.surfaceSoft),
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
              child: Text(
                '$count',
                style: _communityTextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final bool outlined;

  const _Badge({super.key, required this.label, this.outlined = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: outlined ? 8 : 10,
      vertical: outlined ? 2 : 4,
    ),
    decoration: BoxDecoration(
      color: outlined ? AppV2Tokens.surfaceSoft : AppV2Tokens.border,
      border: outlined ? Border.all(color: AppV2Tokens.border) : null,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: _communityTextStyle(
        fontSize: outlined ? 11 : 12,
        fontWeight: FontWeight.w600,
        color: AppV2Tokens.textSecondary,
      ),
    ),
  );
}
