import 'package:flutter/material.dart';

import '../../core/app_v2_tokens.dart';
import '../../core/visuals/app_visual_id.dart';
import '../../models/post.dart';
import '../../widgets/app_more_button.dart';
import '../../widgets/app_visual.dart';
import '../../widgets/preparing_toast.dart';
import 'community_comment_widgets.dart';
import 'community_constants.dart';

String communityCommentAuthor(String value) =>
    value.trim().isEmpty ? '익명집사' : value.trim();

class CommunityCommentsHeader extends StatelessWidget {
  const CommunityCommentsHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.onMore,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('community-comments-header'),
    height: 60,
    child: Padding(
      padding: const EdgeInsets.only(left: 20, right: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: const Key('community-comments-back'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppV2Tokens.primary,
              tooltip: '뒤로가기',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppV2Tokens.text,
                fontFamily: AppV2Tokens.fontFamily,
                fontSize: 24,
                height: 32 / 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: onMore == null
                ? null
                : IconButton(
                    key: const Key('community-comments-more'),
                    onPressed: onMore,
                    icon: const Icon(Icons.more_vert_rounded),
                    color: AppV2Tokens.primary,
                    tooltip: '더보기',
                  ),
          ),
        ],
      ),
    ),
  );
}

class CommunityCommentsSortRow extends StatelessWidget {
  const CommunityCommentsSortRow({super.key, required this.onPopular});
  final VoidCallback onPopular;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: SizedBox(
      key: const Key('community-comments-sort-row'),
      height: 44,
      child: Row(
        children: [
          Semantics(
            button: true,
            selected: true,
            enabled: true,
            child: const _FocusAction(
              key: Key('community-comments-sort-latest'),
              label: '최신순',
              selected: true,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 12, color: AppV2Tokens.border),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            selected: false,
            enabled: true,
            child: _FocusAction(
              key: const Key('community-comments-sort-popular'),
              label: '인기순',
              onPressed: onPopular,
            ),
          ),
        ],
      ),
    ),
  );
}

class CommunityCommentGroup extends StatelessWidget {
  const CommunityCommentGroup({
    super.key,
    required this.root,
    required this.onRootMore,
    required this.onReply,
    required this.onReplyMore,
    this.onLoadEarlierReplies,
    this.loadingReplies = false,
    this.threadKey,
  });

  final PostComment root;
  final VoidCallback onRootMore;
  final VoidCallback onReply;
  final ValueChanged<PostComment> onReplyMore;
  final VoidCallback? onLoadEarlierReplies;
  final bool loadingReplies;
  final Key? threadKey;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: threadKey,
    child: Container(
      key: Key('community-root-${root.id}'),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppV2Tokens.border)),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          _CommentRow(
            comment: root,
            avatarSize: 40,
            bodySize: 16,
            onMore: onRootMore,
            onReply: onReply,
          ),
          if (root.replies.isNotEmpty || onLoadEarlierReplies != null)
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 16),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppV2Tokens.border, width: 2),
                  ),
                ),
                padding: const EdgeInsets.only(left: 14),
                child: Column(
                  children: [
                    if (onLoadEarlierReplies != null)
                      _FocusAction(
                        key: Key('community-replies-load-more-${root.id}'),
                        label: '이전 답글 더보기',
                        loading: loadingReplies,
                        onPressed: loadingReplies ? null : onLoadEarlierReplies,
                      ),
                    for (var i = 0; i < root.replies.length; i++) ...[
                      if (i > 0 || onLoadEarlierReplies != null)
                        const SizedBox(height: 16),
                      _CommentRow(
                        key: Key('community-reply-${root.replies[i].id}'),
                        comment: root.replies[i],
                        avatarSize: 32,
                        bodySize: 14,
                        onMore: () => onReplyMore(root.replies[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    super.key,
    required this.comment,
    required this.avatarSize,
    required this.bodySize,
    required this.onMore,
    this.onReply,
  });

  final PostComment comment;
  final double avatarSize;
  final double bodySize;
  final VoidCallback onMore;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CommunityCommentAvatar(
        key: Key('community-comment-avatar-${comment.id}'),
        url: comment.authorProfileImageUrl,
        size: avatarSize,
        fallbackColor: AppV2Tokens.surfaceSoft,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    communityCommentAuthor(comment.authorNickname),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppV2Tokens.fontFamily,
                      color: AppV2Tokens.text,
                      fontSize: avatarSize == 40 ? 14 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _CommentMoreButton(commentId: comment.id, onPressed: onMore),
              ],
            ),
            Text(
              comment.content,
              style: TextStyle(
                fontFamily: AppV2Tokens.fontFamily,
                color: AppV2Tokens.textSecondary,
                fontSize: bodySize,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  formatCommunityRelativeTime(comment.createdAt) ?? '',
                  style: const TextStyle(
                    fontFamily: AppV2Tokens.fontFamily,
                    color: AppV2Tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onReply != null) ...[
                  const SizedBox(width: 16),
                  _FocusAction(
                    key: Key('community-comment-reply-${comment.id}'),
                    label: '답글 달기',
                    onPressed: onReply,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _CommentMoreButton extends StatefulWidget {
  const _CommentMoreButton({required this.commentId, required this.onPressed});
  final String commentId;
  final VoidCallback onPressed;

  @override
  State<_CommentMoreButton> createState() => _CommentMoreButtonState();
}

class _CommentMoreButtonState extends State<_CommentMoreButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (value) => setState(() => focused = value),
    child: Container(
      key: Key('community-comment-more-${widget.commentId}-focus'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: focused ? AppV2Tokens.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: AppMoreButton.plain(
        key: Key('community-comment-more-${widget.commentId}'),
        tooltip: '댓글 메뉴',
        onPressed: widget.onPressed,
      ),
    ),
  );
}

class _FocusAction extends StatefulWidget {
  const _FocusAction({
    super.key,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool loading;

  @override
  State<_FocusAction> createState() => _FocusActionState();
}

class _FocusActionState extends State<_FocusAction> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (value) => setState(() => focused = value),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? AppV2Tokens.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextButton(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 4),
          ),
          overlayColor: const WidgetStatePropertyAll(AppV2Tokens.primarySoft),
          foregroundColor: WidgetStatePropertyAll(
            widget.selected ? AppV2Tokens.primary : AppV2Tokens.textSecondary,
          ),
        ),
        onPressed: widget.onPressed ?? (widget.selected ? () {} : null),
        child: widget.loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: AppV2Tokens.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ),
  );
}

enum CommunityCommentMenuKind { commentOwner, postOwner, viewer }

Future<void> showCommunityCommentsV2Menu(
  BuildContext context, {
  required CommunityCommentMenuKind kind,
}) async {
  final actions = switch (kind) {
    CommunityCommentMenuKind.commentOwner => const [
      ('수정하기', Icons.edit_outlined, false),
      ('삭제하기', Icons.delete_outline_rounded, true),
    ],
    CommunityCommentMenuKind.postOwner => const [
      ('삭제하기', Icons.delete_outline_rounded, true),
    ],
    CommunityCommentMenuKind.viewer => const [
      ('신고하기', Icons.report_outlined, false),
      ('사용자 차단', Icons.block_rounded, false),
    ],
  };
  final selected = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppV2Tokens.background,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                minTileHeight: 52,
                leading: Icon(
                  action.$2,
                  color: action.$3 ? AppV2Tokens.error : AppV2Tokens.text,
                ),
                title: Text(
                  action.$1,
                  style: TextStyle(
                    color: action.$3 ? AppV2Tokens.error : AppV2Tokens.text,
                    fontFamily: AppV2Tokens.fontFamily,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
          ],
        ),
      ),
    ),
  );
  if (selected == true && context.mounted) showPreparingToast(context);
}

class CommunityCommentsStatus extends StatelessWidget {
  const CommunityCommentsStatus({
    super.key,
    required this.message,
    this.onRetry,
    this.loading = false,
    this.empty = false,
  });
  final String message;
  final VoidCallback? onRetry;
  final bool loading;
  final bool empty;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: loading
          ? const _CommentsSkeleton()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (empty) ...[
                  const AppVisual(id: AppVisualId.communityPaw, size: 42),
                  const SizedBox(height: 10),
                ],
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppV2Tokens.textSecondary,
                    fontFamily: AppV2Tokens.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  _FocusAction(label: '재시도', onPressed: onRetry),
                ],
              ],
            ),
    ),
  );
}

class _CommentsSkeleton extends StatelessWidget {
  const _CommentsSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('community-comments-skeleton'),
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      3,
      (_) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: AppV2Tokens.surfaceSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Container(height: 12, color: AppV2Tokens.surfaceSoft),
                  const SizedBox(height: 10),
                  Container(height: 36, color: AppV2Tokens.surfaceSoft),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CommunityCommentsComposer extends StatelessWidget {
  const CommunityCommentsComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.canSubmit,
    required this.submitting,
    required this.onSubmit,
    required this.onCancelReply,
    this.replyTo,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool canSubmit;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onCancelReply;
  final String? replyTo;

  @override
  Widget build(BuildContext context) {
    final author = replyTo == null ? null : communityCommentAuthor(replyTo!);
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          key: const Key('community-comments-composer'),
          decoration: const BoxDecoration(
            color: AppV2Tokens.background,
            border: Border(top: BorderSide(color: AppV2Tokens.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (author != null)
                SizedBox(
                  key: const Key('community-reply-composer-target'),
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$author님에게 답글',
                          style: const TextStyle(
                            fontFamily: AppV2Tokens.fontFamily,
                            color: AppV2Tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('community-reply-cancel'),
                        onPressed: onCancelReply,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: '답글 취소',
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton.filled(
                      key: const Key('community-comment-image-button'),
                      style: const ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          AppV2Tokens.surfaceSoft,
                        ),
                        foregroundColor: WidgetStatePropertyAll(
                          AppV2Tokens.primary,
                        ),
                      ),
                      onPressed: () => showPreparingToast(context),
                      icon: const Icon(Icons.photo_camera_outlined),
                      tooltip: '이미지 첨부',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('community-comments-input'),
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(
                        fontFamily: AppV2Tokens.fontFamily,
                      ),
                      decoration: InputDecoration(
                        hintText: author == null
                            ? '댓글을 해주세요'
                            : '$author님에게 답글 하기',
                        filled: true,
                        fillColor: AppV2Tokens.surfaceSoft,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppV2Tokens.primary,
                            width: 2,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    enabled: canSubmit && !submitting,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filled(
                        key: const Key('community-comments-submit'),
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            canSubmit && !submitting
                                ? AppV2Tokens.primary
                                : AppV2Tokens.surfaceSoft,
                          ),
                          foregroundColor: WidgetStatePropertyAll(
                            canSubmit && !submitting
                                ? Colors.white
                                : AppV2Tokens.textSecondary,
                          ),
                        ),
                        onPressed: canSubmit && !submitting ? onSubmit : null,
                        icon: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppV2Tokens.primary,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        tooltip: '전송',
                      ),
                    ),
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
