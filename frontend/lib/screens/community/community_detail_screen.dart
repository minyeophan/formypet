import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/keyboard_utils.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_more_button.dart';
import '../../widgets/app_text.dart';
import '../../widgets/authenticated_network_image.dart';
import '../../widgets/preparing_toast.dart';
import 'community_comment_widgets.dart';
import 'community_constants.dart';
import 'community_routes.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final String? sourceKey;

  const CommunityDetailScreen({
    super.key,
    required this.postId,
    this.sourceKey,
  });

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  final _scrollController = ScrollController();
  List<PostComment> _comments = const [];
  bool _loading = true;
  bool _postLoadFailed = false;
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _postLoadFailed = false;
    });

    try {
      await ref.read(communityProvider.notifier).loadPost(widget.postId);
    } catch (_) {
      _postLoadFailed = true;
    }

    try {
      final feed = await ref
          .read(communityServiceProvider)
          .getComments(widget.postId, limit: 5);
      _comments = feed.items.take(5).toList();
    } catch (_) {
      if (_comments.isEmpty) _comments = const [];
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleLike(Post post) async {
    if (_liking) return;
    setState(() => _liking = true);
    try {
      await ref.read(communityProvider.notifier).toggleLike(post.id);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _openComments({bool focus = false}) async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    await context.push(
      communityCommentsPath(widget.postId, widget.sourceKey, focus: focus),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(communityProvider).postsById[widget.postId];
    final currentUserId = ref.watch(
      authProvider.select((state) => state.profile?.id),
    );
    final title = _headerTitle(post);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _DetailHeader(
              title: title,
              onBack: _goBack,
              onMore: post == null ? null : _showPostMoreMenu,
            ),
            Expanded(
              child: _loading && post == null
                  ? const Center(child: CircularProgressIndicator())
                  : post == null && _postLoadFailed
                  ? const Center(child: AppText('게시글을 찾을 수 없습니다'))
                  : post == null
                  ? const Center(child: AppText('게시글을 찾을 수 없습니다'))
                  : _DetailBody(
                      controller: _scrollController,
                      post: post,
                      comments: _comments.take(5).toList(),
                      currentUserId: currentUserId,
                      onVote: (optionId) => ref
                          .read(communityProvider.notifier)
                          .vote(post.id, optionId),
                      onCommentMore: () =>
                          showCommunityCommentMoreMenu(context),
                      onFirstComment: () => _openComments(focus: true),
                      onMoreComments: () => _openComments(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: post == null
          ? null
          : _DetailBottomActionBar(
              post: post,
              liking: _liking,
              onTop: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              ),
              onLike: () => _toggleLike(post),
              onComment: () => _openComments(focus: true),
            ),
    );
  }

  String _headerTitle(Post? post) {
    final sourceLabel = communitySourceLabel(widget.sourceKey);
    if (sourceLabel.isNotEmpty) return sourceLabel;
    final postLabel = communitySourceLabel(post?.category);
    return postLabel.isNotEmpty ? postLabel : '게시글';
  }

  void _goBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(communityFallbackPath(widget.sourceKey));
    }
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
}

class _DetailHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onMore;

  const _DetailHeader({required this.title, required this.onBack, this.onMore});

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
        Expanded(
          child: AppText(
            title,
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
  final ScrollController controller;
  final Post post;
  final List<PostComment> comments;
  final String? currentUserId;
  final Future<Post> Function(String optionId) onVote;
  final VoidCallback onCommentMore;
  final VoidCallback onFirstComment;
  final VoidCallback onMoreComments;

  const _DetailBody({
    required this.controller,
    required this.post,
    required this.comments,
    required this.currentUserId,
    required this.onVote,
    required this.onCommentMore,
    required this.onFirstComment,
    required this.onMoreComments,
  });

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('community-detail-scroll'),
    controller: controller,
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 108),
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
      if (post.poll != null) ...[
        const SizedBox(height: 20),
        _PollCard(poll: post.poll!, onVote: onVote),
      ],
      const SizedBox(height: 24),
      if (comments.isEmpty)
        _FirstCommentButton(onPressed: onFirstComment)
      else ...[
        for (var i = 0; i < comments.length; i++)
          CommunityCommentTile(
            key: i == 0
                ? const Key('community-detail-first-comment')
                : Key('community-detail-comment-${comments[i].id}'),
            comment: comments[i],
            canManage: canManageCommunityComment(
              currentUserId: currentUserId,
              post: post,
              comment: comments[i],
            ),
            onMore: onCommentMore,
          ),
        if (post.commentsCount > comments.length)
          TextButton(
            key: const Key('community-detail-more-comments'),
            onPressed: onMoreComments,
            child: AppText(
              '댓글 ${post.commentsCount}개 더보기',
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    ],
  );
}

class _FirstCommentButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _FirstCommentButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: InkWell(
      key: const Key('community-detail-first-comment'),
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Center(
          child: AppText(
            '첫 댓글쓰기',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ),
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
    return Material(
      key: const Key('community-detail-poll'),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
      ),
    );
  }
}

class _DetailBottomActionBar extends StatelessWidget {
  final Post post;
  final bool liking;
  final VoidCallback onTop;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _DetailBottomActionBar({
    required this.post,
    required this.liking,
    required this.onTop,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: AppColors.surface,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('community-detail-top-button'),
                  tooltip: '맨 위로',
                  onPressed: onTop,
                  icon: const Text('🔝', style: TextStyle(fontSize: 21)),
                ),
                const Spacer(),
                TextButton.icon(
                  key: const Key('community-detail-bottom-like'),
                  onPressed: liking ? null : onLike,
                  icon: Icon(
                    post.liked ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: post.liked ? Colors.red : AppColors.textSecondary,
                  ),
                  label: AppText('${post.likesCount}', fontSize: 13),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  key: const Key('community-detail-bottom-comment'),
                  onPressed: onComment,
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  label: AppText('${post.commentsCount}', fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
