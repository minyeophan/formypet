import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../models/post.dart';
import '../../../widgets/app_action_sheet.dart';
import '../../../widgets/app_more_button.dart';
import '../../../widgets/app_navigation.dart';
import '../../../widgets/app_text.dart';
import 'community_detail_widgets.dart';
import 'community_mock_provider.dart';

class CommunityMockDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const CommunityMockDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<CommunityMockDetailScreen> createState() =>
      _CommunityMockDetailScreenState();
}

class _CommunityMockDetailScreenState
    extends ConsumerState<CommunityMockDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/community/mock');
    }
  }

  void _submitComment() {
    ref
        .read(mockCommunityProvider.notifier)
        .addComment(widget.postId, _commentController.text);
    if (_commentController.text.trim().isNotEmpty) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockCommunityProvider);
    final post = state.postById(widget.postId);
    if (post == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: AppBackButton(onPressed: _goBack),
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
        ),
        body: const Center(
          child: AppText(
            '게시글을 찾을 수 없어요.',
            key: Key('mock-community-post-not-found'),
          ),
        ),
      );
    }

    final comments = state.commentsFor(post.id);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: AppBackButton(onPressed: _goBack),
        title: const AppText('게시글 상세', fontWeight: FontWeight.w700),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppMoreButton.surface(
              key: const Key('mock-post-more-button'),
              onPressed: _showPostMoreMenu,
            ),
          ),
        ],
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
      ),
      body: ListView(
        key: const Key('mock-detail-scroll'),
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: AppText(
                    _categoryLabel(post.category),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Divider(height: 32, color: AppColors.border),
                AppText(
                  _categoryLabel(post.category),
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 5),
                AppText(
                  post.title ?? '',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                const Divider(height: 30, color: AppColors.border),
                const AppText('익명마미', fontWeight: FontWeight.w700),
                const SizedBox(height: 7),
                const AppText(
                  '한시간 전  조회수 1,093',
                  fontSize: 12,
                  color: AppColors.muted,
                ),
                const Divider(height: 30, color: AppColors.border),
                AppText(post.content.trim(), fontSize: 15),
                if (post.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  CommunityImageGallery(imageUrls: post.imageUrls),
                ],
                if (post.poll != null) ...[
                  const SizedBox(height: 18),
                  CommunityPollCard(
                    poll: post.poll!,
                    onVote: (optionId) => ref
                        .read(mockCommunityProvider.notifier)
                        .vote(post.id, optionId),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(
                      post.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: post.liked
                          ? Colors.redAccent
                          : AppColors.textSecondary,
                      size: 19,
                    ),
                    const SizedBox(width: 6),
                    AppText('좋아요 ${post.likesCount}', fontSize: 13),
                    const Spacer(),
                    const AppText('공유하기', fontSize: 13),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 10, color: AppColors.background),
          _CommentsBlock(
            post: post,
            comments: comments,
            commentsCount: state.commentsCountFor(post.id),
            onMore: _showCommentMoreMenu,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TextField(
                      key: const Key('mock-comment-input'),
                      controller: _commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                      decoration: const InputDecoration(
                        hintText: '댓글을 입력하세요...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('mock-comment-submit'),
                  tooltip: '댓글 등록',
                  onPressed: _submitComment,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String category) =>
      category == '훈훈익명' ? category : category;

  void _showPostMoreMenu() {
    showAppActionSheet(
      context,
      title: '더보기 메뉴',
      actions: const [
        AppActionSheetItem(key: Key('mock-post-report'), label: '신고하기'),
      ],
    );
  }

  void _showCommentMoreMenu(MockCommunityComment _) {
    showAppActionSheet(
      context,
      title: '댓글 관리',
      actions: const [AppActionSheetItem(label: '삭제하기')],
    );
  }
}

class _CommentsBlock extends StatelessWidget {
  final Post post;
  final List<MockCommunityComment> comments;
  final int commentsCount;
  final ValueChanged<MockCommunityComment> onMore;

  const _CommentsBlock({
    required this.post,
    required this.comments,
    required this.commentsCount,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: AppText('댓글 $commentsCount개', fontWeight: FontWeight.w700),
          ),
          const Divider(height: 28, color: AppColors.border),
          if (comments.isEmpty)
            const AppText('첫 댓글을 남겨 주세요.', color: AppColors.muted)
          else
            for (var index = 0; index < comments.length; index++) ...[
              _CommentTile(
                post: post,
                comment: comments[index],
                isBest: index == 0 && post.id == 'story-1',
                score: switch (index) {
                  0 => 5,
                  1 => 0,
                  _ => 1,
                },
                onMore: onMore,
              ),
              if (index != comments.length - 1)
                const Divider(height: 28, color: AppColors.border),
            ],
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Post post;
  final MockCommunityComment comment;
  final bool isBest;
  final int score;
  final ValueChanged<MockCommunityComment> onMore;

  const _CommentTile({
    required this.post,
    required this.comment,
    required this.isBest,
    required this.score,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    const currentUserId = MockCommunityNotifier.currentUserId;
    final canManage =
        post.userId == currentUserId || comment.authorId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppText(comment.authorNickname, fontWeight: FontWeight.w700),
            if (isBest) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFE0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const AppText(
                  'Best',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const Spacer(),
            AppText(comment.createdAt, fontSize: 12, color: AppColors.muted),
            if (canManage)
              AppMoreButton.plain(
                key: Key('mock-comment-more-${comment.id}'),
                tooltip: '댓글 관리',
                onPressed: () => onMore(comment),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppText(comment.content, fontSize: 14),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.thumb_up_alt_outlined, size: 16),
            const SizedBox(width: 5),
            AppText('$score', fontSize: 12),
            const SizedBox(width: 18),
            const AppText('답글쓰기', fontSize: 12),
          ],
        ),
      ],
    );
  }
}
