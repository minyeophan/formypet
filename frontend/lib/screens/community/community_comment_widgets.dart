import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/post.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_more_button.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/preparing_toast.dart';

bool canManageCommunityComment({
  required String? currentUserId,
  required Post post,
  required PostComment comment,
}) {
  return currentUserId != null &&
      (post.userId == currentUserId || comment.userId == currentUserId);
}

void showCommunityCommentMoreMenu(BuildContext context) {
  showAppActionSheet(
    context,
    title: '댓글 관리',
    actions: [
      AppActionSheetItem(
        label: '삭제하기',
        destructive: true,
        onTap: () => showPreparingToast(context),
      ),
    ],
  );
}

class CommunityCommentAvatar extends StatelessWidget {
  final String? url;
  final double size;

  const CommunityCommentAvatar({super.key, required this.url, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final fallback = Material(
      color: AppColors.surfaceSoft,
      shape: const CircleBorder(),
      child: SizedBox(
        width: size,
        height: size,
        child: const Center(child: Text('🐾', style: TextStyle(fontSize: 16))),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: AuthenticatedNetworkImage(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}

class CommunityCommentTile extends StatelessWidget {
  final PostComment comment;
  final bool canManage;
  final VoidCallback onMore;
  final Key? moreKey;
  final bool isReply;
  final VoidCallback? onReply;

  const CommunityCommentTile({
    super.key,
    required this.comment,
    required this.canManage,
    required this.onMore,
    this.moreKey,
    this.isReply = false,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) => Card(
    key: Key(
      isReply
          ? 'community-reply-${comment.id}'
          : 'community-root-${comment.id}',
    ),
    margin: EdgeInsets.only(left: isReply ? 36 : 0, bottom: 10),
    color: isReply ? AppColors.surfaceSoft : AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommunityCommentAvatar(
                key: Key('community-comment-avatar-${comment.id}'),
                url: comment.authorProfileImageUrl,
                size: isReply ? 28 : 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  comment.authorNickname,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (canManage)
                AppMoreButton.plain(
                  key: moreKey ?? Key('community-comment-more-${comment.id}'),
                  tooltip: '댓글 관리',
                  onPressed: onMore,
                )
              else
                const SizedBox(width: 44, height: 44),
            ],
          ),
          const SizedBox(height: 8),
          AppText(comment.content, fontSize: 14),
          if (!isReply && onReply != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: Key('community-comment-reply-${comment.id}'),
              onPressed: onReply,
              icon: const Icon(Icons.reply_rounded, size: 17),
              label: const AppText('답글쓰기', fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}
