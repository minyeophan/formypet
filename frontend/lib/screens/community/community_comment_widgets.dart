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

  const CommunityCommentAvatar({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Material(
      color: AppColors.surfaceSoft,
      shape: const CircleBorder(),
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Center(child: Text('🐾', style: TextStyle(fontSize: 16))),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: AuthenticatedNetworkImage(
        url: url,
        width: 32,
        height: 32,
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

  const CommunityCommentTile({
    super.key,
    required this.comment,
    required this.canManage,
    required this.onMore,
    this.moreKey,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: AppColors.surface,
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
              CommunityCommentAvatar(url: comment.authorProfileImageUrl),
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
        ],
      ),
    ),
  );
}
