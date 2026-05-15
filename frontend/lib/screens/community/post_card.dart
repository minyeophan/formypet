import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../core/date_utils.dart';
import '../../widgets/app_text.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;

  const PostCard({super.key, required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: AppText(
                    post.authorNickname.isNotEmpty
                        ? post.authorNickname[0]
                        : '?',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(post.authorNickname,
                          fontWeight: FontWeight.bold, fontSize: 13),
                      AppText(
                        post.createdAt.isNotEmpty
                            ? formatDateShort(post.createdAt.substring(0, 10))
                            : '',
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (post.title != null) ...[
              const SizedBox(height: 8),
              AppText(post.title!, fontWeight: FontWeight.bold, fontSize: 15),
            ],
            const SizedBox(height: 6),
            AppText(post.content, fontSize: 14, maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: onLike,
                  child: Row(
                    children: [
                      Icon(
                        post.liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: post.liked ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      AppText('${post.likesCount}', fontSize: 13),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                AppText('${post.commentsCount}', fontSize: 13),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
