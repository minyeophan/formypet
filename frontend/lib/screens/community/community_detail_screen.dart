import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_more_button.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/preparing_toast.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const CommunityDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  final _commentController = TextEditingController();
  List<PostComment> _comments = const [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await ref.read(communityProvider.notifier).loadPost(widget.postId);
      final comments = await ref
          .read(communityServiceProvider)
          .getComments(widget.postId);
      if (mounted) setState(() => _comments = comments.items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final comment = await ref
          .read(communityProvider.notifier)
          .createComment(widget.postId, content);
      if (!mounted) return;
      _commentController.clear();
      setState(() => _comments = [comment, ..._comments]);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(communityProvider).postsById[widget.postId];
    final currentUserId = ref.watch(
      authProvider.select((state) => state.profile?.id),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _DetailHeader(
              onBack: () {
                FocusManager.instance.primaryFocus?.unfocus();
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go('/community');
                }
              },
              onMore: post == null ? null : _showPostMoreMenu,
            ),
            Expanded(
              child: _loading && post == null
                  ? const Center(child: CircularProgressIndicator())
                  : post == null
                  ? const Center(child: AppText('게시글을 찾을 수 없습니다'))
                  : _DetailBody(
                      post: post,
                      comments: _comments,
                      currentUserId: currentUserId,
                      onLike: () => ref
                          .read(communityProvider.notifier)
                          .toggleLike(post.id),
                      onVote: (optionId) => ref
                          .read(communityProvider.notifier)
                          .vote(post.id, optionId),
                      onCommentMore: _showCommentMoreMenu,
                    ),
            ),
            _CommentComposer(
              controller: _commentController,
              submitting: _submitting,
              onSubmit: _submitComment,
            ),
          ],
        ),
      ),
    );
  }

  void _showPostMoreMenu() {
    showAppActionSheet(
      context,
      title: '더보기 메뉴',
      actions: [
        AppActionSheetItem(
          label: '신고하기',
          onTap: () => showPreparingToast(context),
        ),
      ],
    );
  }

  void _showCommentMoreMenu(PostComment _) {
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
}

class _DetailHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onMore;

  const _DetailHeader({required this.onBack, this.onMore});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: IconButton(
            key: const Key('community-detail-back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        const Expanded(
          child: AppText(
            '게시글',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: onMore == null
                ? const SizedBox(width: 38, height: 38)
                : AppMoreButton.surface(
                    key: const Key('community-detail-more-button'),
                    onPressed: onMore,
                  ),
          ),
        ),
      ],
    ),
  );
}

class _DetailBody extends StatelessWidget {
  final Post post;
  final List<PostComment> comments;
  final String? currentUserId;
  final VoidCallback onLike;
  final Future<Post> Function(String optionId) onVote;
  final ValueChanged<PostComment> onCommentMore;

  const _DetailBody({
    required this.post,
    required this.comments,
    required this.currentUserId,
    required this.onLike,
    required this.onVote,
    required this.onCommentMore,
  });

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('community-detail-scroll'),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    children: [
      AppText(
        post.title?.trim().isNotEmpty == true
            ? post.title!.trim()
            : post.content,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      const SizedBox(height: 8),
      AppText(post.authorNickname, fontSize: 12, color: AppColors.muted),
      const SizedBox(height: 16),
      if (post.title?.trim().isNotEmpty == true)
        AppText(post.content, fontSize: 15, color: AppColors.textSecondary),
      if (post.imageUrls.isNotEmpty) ...[
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: post.imageUrls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AuthenticatedNetworkImage(
                url: post.imageUrls[index],
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                fallback: const ColoredBox(color: AppColors.surfaceSoft),
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      _LikeAndCommentRow(post: post, onLike: onLike),
      if (post.poll != null) ...[
        const SizedBox(height: 20),
        _PollCard(poll: post.poll!, onVote: onVote),
      ],
      const SizedBox(height: 24),
      AppText(
        '댓글 ${post.commentsCount}',
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      const SizedBox(height: 10),
      for (final comment in comments)
        _CommentTile(
          comment: comment,
          canManage:
              currentUserId != null &&
              (post.userId == currentUserId || comment.userId == currentUserId),
          onMore: () => onCommentMore(comment),
        ),
    ],
  );
}

class _LikeAndCommentRow extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  const _LikeAndCommentRow({required this.post, required this.onLike});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      InkWell(
        key: const Key('community-detail-like'),
        onTap: onLike,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              post.liked ? Icons.favorite : Icons.favorite_border,
              size: 19,
              color: post.liked ? Colors.red : AppColors.muted,
            ),
            const SizedBox(width: 5),
            AppText('${post.likesCount}', fontSize: 13),
          ],
        ),
      ),
      const SizedBox(width: 16),
      const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.muted),
      const SizedBox(width: 5),
      AppText('${post.commentsCount}', fontSize: 13),
    ],
  );
}

class _PollCard extends StatelessWidget {
  final PostPoll poll;
  final Future<Post> Function(String optionId) onVote;
  const _PollCard({required this.poll, required this.onVote});
  @override
  Widget build(BuildContext context) {
    final total = poll.options.fold(
      0,
      (sum, option) => sum + option.votesCount,
    );
    return Container(
      key: const Key('community-detail-poll'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(poll.question, fontWeight: FontWeight.bold),
          const SizedBox(height: 10),
          for (final option in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: Key('community-poll-option-${option.id}'),
                onPressed: () => onVote(option.id),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText(option.text, color: AppColors.text),
                    ),
                    AppText(
                      '${total == 0 ? 0 : (option.votesCount * 100 / total).round()}%',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final bool canManage;
  final VoidCallback onMore;
  const _CommentTile({
    required this.comment,
    required this.canManage,
    required this.onMore,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                comment.authorNickname,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (canManage)
              AppMoreButton.plain(
                key: Key('community-comment-more-${comment.id}'),
                tooltip: '댓글 관리',
                onPressed: onMore,
              ),
          ],
        ),
        const SizedBox(height: 3),
        AppText(comment.content, fontSize: 14),
      ],
    ),
  );
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  const _CommentComposer({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('community-comment-input'),
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
            ),
          ),
          IconButton(
            key: const Key('community-comment-submit'),
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    ),
  );
}
