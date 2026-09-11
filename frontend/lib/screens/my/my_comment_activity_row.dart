import 'package:flutter/material.dart';
import '../../core/app_v2_tokens.dart';
import '../../models/my_community_activity.dart';
import '../../widgets/app_ink_well.dart';
import '../community/community_constants.dart';

class MyCommentActivityRow extends StatelessWidget {
  const MyCommentActivityRow({
    super.key,
    required this.activity,
    required this.onOpenComment,
  });
  final MyCommunityActivity activity;
  final VoidCallback? onOpenComment;

  @override
  Widget build(BuildContext context) {
    final title = activity.post.title?.trim() ?? '';
    final time = formatCommunityRelativeTime(activity.activityAt);
    return Material(
      color: AppV2Tokens.surface,
      child: AppInkWell(
        onTap: onOpenComment,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppV2Tokens.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '내 댓글',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppV2Tokens.primaryPressed,
                      ),
                    ),
                  ),
                  if (time != null)
                    Flexible(
                      child: Text(
                        time,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppV2Tokens.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activity.commentContent?.trim().isNotEmpty == true
                          ? activity.commentContent!
                          : '댓글 내용을 확인할 수 없어요.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: AppV2Tokens.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const ExcludeSemantics(
                    child: Text(
                      '›',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppV2Tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    '원문',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppV2Tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title.isEmpty ? '제목 없음' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppV2Tokens.textSecondary,
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
