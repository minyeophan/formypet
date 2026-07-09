import 'package:flutter/material.dart';

import '../../core/app_v2_tokens.dart';
import '../../core/visuals/app_visual_id.dart';
import '../../models/post.dart';
import '../../widgets/app_more_button.dart';
import '../../widgets/app_visual.dart';
import '../../widgets/authenticated_network_image.dart';
import 'community_comment_widgets.dart';
import 'community_constants.dart';

TextStyle communityV2Style({
  double? size,
  FontWeight? weight,
  Color? color,
  double? height,
}) => TextStyle(
  fontFamily: AppV2Tokens.fontFamily,
  fontSize: size,
  fontWeight: weight,
  color: color ?? AppV2Tokens.text,
  height: height,
);

class CommunityDetailArticle extends StatelessWidget {
  const CommunityDetailArticle({
    super.key,
    required this.post,
    required this.onLike,
    required this.likeEnabled,
    required this.onVote,
    required this.voteBusy,
    required this.commentsCount,
  });
  final Post post;
  final VoidCallback onLike;
  final bool likeEnabled;
  final Future<void> Function(String optionId) onVote;
  final bool voteBusy;
  final int commentsCount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        key: const Key('community-detail-author'),
        children: [
          CommunityCommentAvatar(
            key: const Key('community-detail-author-avatar'),
            url: post.authorProfileImageUrl,
            size: 40,
            fallbackColor: AppV2Tokens.surfaceSoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorNickname.trim().isEmpty
                      ? '익명집사'
                      : post.authorNickname.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: communityV2Style(size: 14, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCommunityRelativeTime(post.createdAt) ?? '',
                  style: communityV2Style(
                    size: 12,
                    color: AppV2Tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        post.title?.trim().isNotEmpty == true ? post.title!.trim() : '제목 없음',
        style: communityV2Style(size: 24, weight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Text(post.content, style: communityV2Style(size: 16, height: 1.6)),
      if (post.poll != null) ...[
        const SizedBox(height: 20),
        CommunityPollCard(
          key: const Key('community-detail-poll'),
          poll: post.poll!,
          busy: voteBusy,
          onVote: onVote,
        ),
      ],
      if (post.imageUrls.isNotEmpty) ...[
        const SizedBox(height: 20),
        CommunityImagePager(urls: post.imageUrls),
      ],
      const SizedBox(height: 20),
      Row(
        children: [
          _StatButton(
            key: const Key('community-detail-like'),
            icon: post.liked ? Icons.favorite : Icons.favorite_border,
            iconColor: post.liked
                ? AppV2Tokens.error
                : AppV2Tokens.textSecondary,
            label: '${post.likesCount}',
            onTap: likeEnabled ? onLike : null,
          ),
          const SizedBox(width: 8),
          _StatButton(
            key: const Key('community-detail-comment-stat'),
            icon: Icons.chat_bubble_outline_rounded,
            label: '$commentsCount',
          ),
        ],
      ),
      const Divider(
        key: Key('community-detail-content-divider'),
        height: 33,
        color: AppV2Tokens.border,
      ),
    ],
  );
}

class CommunityImagePager extends StatefulWidget {
  const CommunityImagePager({super.key, required this.urls});
  final List<String> urls;
  @override
  State<CommunityImagePager> createState() => _CommunityImagePagerState();
}

class _CommunityImagePagerState extends State<CommunityImagePager> {
  final PageController _controller = PageController();
  int _index = 0;
  @override
  void didUpdateWidget(covariant CommunityImagePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.urls.length) {
      _index = widget.urls.isEmpty ? 0 : widget.urls.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(_index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: PageView.builder(
            key: const Key('community-detail-images'),
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, i) => Semantics(
              label: '이미지 ${i + 1}/${widget.urls.length}',
              image: true,
              child: AuthenticatedNetworkImage(
                url: widget.urls[i],
                fit: BoxFit.cover,
                fallback: const ColoredBox(
                  color: AppV2Tokens.surfaceSoft,
                  child: Center(
                    child: AppVisual(id: AppVisualId.genericUnknown, size: 36),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (widget.urls.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.urls.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index
                        ? AppV2Tokens.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: i == _index
                          ? AppV2Tokens.primary
                          : AppV2Tokens.border,
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class CommunityPollCard extends StatefulWidget {
  const CommunityPollCard({
    super.key,
    required this.poll,
    this.busy = false,
    this.onVote,
  });
  final PostPoll poll;
  final bool busy;
  final Future<void> Function(String optionId)? onVote;
  @override
  State<CommunityPollCard> createState() => _CommunityPollCardState();
}

class _CommunityPollCardState extends State<CommunityPollCard> {
  String? pending;
  String? get server =>
      widget.poll.options.where((o) => o.votedByMe).firstOrNull?.id;
  @override
  void initState() {
    super.initState();
    pending = server;
  }

  @override
  void didUpdateWidget(covariant CommunityPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldServer = oldWidget.poll.options
        .where((o) => o.votedByMe)
        .firstOrNull
        ?.id;
    if (server != oldServer ||
        !widget.poll.options.any((o) => o.id == pending)) {
      pending = server;
    }
  }

  @override
  Widget build(BuildContext context) {
    final voted = server != null;
    final total = widget.poll.options.fold<int>(
      0,
      (sum, item) => sum + item.votesCount,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppV2Tokens.surfaceSoft,
        border: Border.all(color: AppV2Tokens.border),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.poll.question,
            style: communityV2Style(size: 14, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final option in widget.poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                selected: pending == option.id,
                enabled: !widget.busy,
                child: OutlinedButton(
                  key: Key('community-poll-option-${option.id}'),
                  onPressed: widget.busy
                      ? null
                      : () => setState(() => pending = option.id),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: pending == option.id
                        ? AppV2Tokens.primarySoft
                        : Colors.transparent,
                    side: BorderSide(
                      color: pending == option.id
                          ? AppV2Tokens.primary
                          : AppV2Tokens.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (pending == option.id) ...[
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppV2Tokens.primary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          option.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: communityV2Style(size: 14),
                        ),
                      ),
                      if (voted)
                        Text(
                          '${total == 0 ? 0 : ((option.votesCount / total).clamp(0, 1) * 100).round()}%',
                          style: communityV2Style(
                            size: 12,
                            color: AppV2Tokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (voted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$total명 참여',
                style: communityV2Style(
                  size: 12,
                  color: AppV2Tokens.textSecondary,
                ),
              ),
            ),
          Semantics(
            enabled: pending != null && !widget.busy,
            child: FilledButton(
              key: const Key('community-poll-submit'),
              onPressed: pending == null || widget.busy
                  ? null
                  : () => widget.onVote?.call(pending!),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: AppV2Tokens.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                voted && pending != server ? '투표 변경' : '투표하기',
                style: communityV2Style(
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityCommentPreview extends StatelessWidget {
  const CommunityCommentPreview({
    super.key,
    required this.post,
    required this.comments,
    required this.currentUserId,
    required this.total,
    required this.hasMore,
    required this.onMore,
    required this.onReply,
    required this.onThread,
    required this.onManage,
  });
  final Post post;
  final List<PostComment> comments;
  final String? currentUserId;
  final int total;
  final bool hasMore;
  final VoidCallback onMore;
  final ValueChanged<String> onReply;
  final ValueChanged<String> onThread;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return Text(
        '소중한 첫 댓글을 남겨주세요',
        style: communityV2Style(size: 14, color: AppV2Tokens.textSecondary),
      );
    }
    return Column(
      children: [
        for (final root in comments)
          _CommentRow(
            post: post,
            comment: root,
            currentUserId: currentUserId,
            onReply: () => onReply(root.id),
            onThread: () => onThread(root.id),
            onManage: onManage,
          ),
        if (hasMore)
          Align(
            alignment: Alignment.centerLeft,
            child: _LinkButton(
              key: const Key('community-detail-more-comments'),
              label: '댓글 더보기',
              onPressed: onMore,
            ),
          ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.post,
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onThread,
    required this.onManage,
  });
  final Post post;
  final PostComment comment;
  final String? currentUserId;
  final VoidCallback onReply;
  final VoidCallback onThread;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) {
    final uniqueReplies = <String, PostComment>{
      for (final reply in comment.replies) reply.id: reply,
    }.values.take(2).toList();
    final remaining = (comment.replyCount - uniqueReplies.length).clamp(
      0,
      comment.replyCount,
    );
    return Column(
      key: Key('community-root-${comment.id}'),
      children: [
        _FlatComment(
          comment: comment,
          canManage: canManageCommunityComment(
            currentUserId: currentUserId,
            post: post,
            comment: comment,
          ),
          onManage: onManage,
          onReply: onReply,
        ),
        for (final reply in uniqueReplies)
          Container(
            key: Key('community-reply-${reply.id}'),
            margin: const EdgeInsets.only(left: 40),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppV2Tokens.border, width: 2),
              ),
            ),
            padding: const EdgeInsets.only(left: 12),
            child: _FlatComment(
              comment: reply,
              reply: true,
              canManage: canManageCommunityComment(
                currentUserId: currentUserId,
                post: post,
                comment: reply,
              ),
              onManage: onManage,
            ),
          ),
        if (remaining > 0 || comment.repliesNextCursor != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _LinkButton(
                key: Key('community-detail-more-replies-${comment.id}'),
                label: remaining > 0 ? '답글 $remaining개 더보기' : '답글 더보기',
                onPressed: onThread,
              ),
            ),
          ),
      ],
    );
  }
}

class _FlatComment extends StatelessWidget {
  const _FlatComment({
    required this.comment,
    required this.canManage,
    required this.onManage,
    this.onReply,
    this.reply = false,
  });
  final PostComment comment;
  final bool canManage;
  final VoidCallback onManage;
  final VoidCallback? onReply;
  final bool reply;
  @override
  Widget build(BuildContext context) {
    if (comment.deleted) {
      return Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppV2Tokens.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '삭제된 댓글입니다',
          style: communityV2Style(
            size: 14,
            color: AppV2Tokens.textSecondary,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }
    return Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppV2Tokens.border)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommunityCommentAvatar(
          key: Key('community-comment-avatar-${comment.id}'),
          url: comment.authorProfileImageUrl,
          size: reply ? 28 : 32,
          fallbackColor: AppV2Tokens.surfaceSoft,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.authorNickname.trim().isEmpty
                    ? '익명집사'
                    : comment.authorNickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: communityV2Style(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(comment.content, style: communityV2Style(size: 14)),
              if (onReply != null)
                _LinkButton(
                  key: Key('community-comment-reply-${comment.id}'),
                  label: '답글쓰기',
                  onPressed: onReply!,
                ),
            ],
          ),
        ),
        if (canManage)
          AppMoreButton.plain(
            key: Key('community-comment-more-${comment.id}'),
            tooltip: '댓글 관리',
            onPressed: onManage,
            plainColor: AppV2Tokens.textSecondary,
            plainSplashColor: AppV2Tokens.primarySoft,
          )
        else
          const SizedBox(width: 44),
      ],
    ),
  );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => _FocusOutline(
    focusKey: _derivedFocusKey(key),
    child: TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppV2Tokens.textSecondary,
        backgroundColor: Colors.transparent,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Text(
        label,
        style: communityV2Style(
          size: 12,
          weight: FontWeight.w600,
          color: AppV2Tokens.textSecondary,
        ),
      ),
    ),
  );
}

class _StatButton extends StatelessWidget {
  const _StatButton({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = AppV2Tokens.textSecondary,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _FocusOutline(
    focusKey: _derivedFocusKey(key),
    child: Semantics(
      button: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        splashColor: AppV2Tokens.primary.withValues(alpha: .08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: communityV2Style(
                  size: 13,
                  color: AppV2Tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Key? _derivedFocusKey(Key? key) {
  if (key is ValueKey<String>) return Key('${key.value}-focus');
  return null;
}

class _FocusOutline extends StatefulWidget {
  const _FocusOutline({required this.child, this.focusKey});
  final Widget child;
  final Key? focusKey;

  @override
  State<_FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<_FocusOutline> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    skipTraversal: true,
    onFocusChange: (focused) => setState(() => _focused = focused),
    child: Container(
      key: _focused ? widget.focusKey : null,
      decoration: _focused
          ? BoxDecoration(
              border: Border.all(color: AppV2Tokens.primary, width: 2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: widget.child,
    ),
  );
}

class CommunityDetailSkeleton extends StatelessWidget {
  const CommunityDetailSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Skeleton(width: 150, height: 40),
        SizedBox(height: 24),
        _Skeleton(width: 220, height: 28),
        SizedBox(height: 16),
        _Skeleton(width: double.infinity, height: 80),
        SizedBox(height: 24),
        _Skeleton(width: 130, height: 44),
      ],
    ),
  );
}

class CommunityCommentSkeleton extends StatelessWidget {
  const CommunityCommentSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      _Skeleton(width: double.infinity, height: 64),
      SizedBox(height: 10),
      _Skeleton(width: double.infinity, height: 64),
      SizedBox(height: 10),
      _Skeleton(width: double.infinity, height: 64),
    ],
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppV2Tokens.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
