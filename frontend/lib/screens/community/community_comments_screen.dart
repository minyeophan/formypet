import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_text.dart';
import '../../widgets/preparing_toast.dart';
import 'community_comment_widgets.dart';
import 'community_routes.dart';

class CommunityCommentsScreen extends ConsumerStatefulWidget {
  final String postId;
  final String? sourceKey;
  final bool autofocus;

  const CommunityCommentsScreen({
    super.key,
    required this.postId,
    this.sourceKey,
    this.autofocus = false,
  });

  @override
  ConsumerState<CommunityCommentsScreen> createState() =>
      _CommunityCommentsScreenState();
}

class _CommunityCommentsScreenState
    extends ConsumerState<CommunityCommentsScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  List<PostComment> _comments = const [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _submitting = false;
  String? _errorText;
  int _displayedCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    final cached = ref.read(communityProvider).postsById[widget.postId];
    _displayedCount = cached?.commentsCount ?? 0;
    _load();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onInputChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    _errorText = null;
    Post? refreshedPost;
    Object? commentsError;

    Future<void> refreshPost() async {
      try {
        refreshedPost = await ref
            .read(communityProvider.notifier)
            .loadPost(widget.postId);
      } catch (_) {
        // Comments can still render from the comments API or cached post state.
      }
    }

    final postFuture = refreshPost();

    try {
      final feed = await ref
          .read(communityServiceProvider)
          .getComments(widget.postId, limit: 20);
      _comments = feed.items;
      _nextCursor = feed.nextCursor;
    } catch (error) {
      commentsError = error;
    }

    await postFuture;

    final cached = ref.read(communityProvider).postsById[widget.postId];
    final baseCount =
        refreshedPost?.commentsCount ?? cached?.commentsCount ?? 0;
    _displayedCount = max(baseCount, _comments.length);
    if (commentsError != null && _comments.isEmpty) {
      _errorText = '댓글을 불러오지 못했습니다';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final feed = await ref
          .read(communityServiceProvider)
          .getComments(widget.postId, cursor: cursor, limit: 20);
      final ids = _comments.map((comment) => comment.id).toSet();
      _comments = [
        ..._comments,
        ...feed.items.where((comment) => !ids.contains(comment.id)),
      ];
      _nextCursor = feed.nextCursor;
      _displayedCount = max(_displayedCount, _comments.length);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final comment = await ref
          .read(communityProvider.notifier)
          .createComment(widget.postId, content);
      if (!mounted) return;
      final exists = _comments.any((item) => item.id == comment.id);
      if (!exists) {
        _comments = [comment, ..._comments];
      }
      final inserted = exists ? 0 : 1;
      _displayedCount = max(_displayedCount + inserted, comment.commentsCount);
      _controller.clear();
      _focusNode.requestFocus();
      setState(() => _submitting = false);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(communityProvider).postsById[widget.postId];
    final currentUserId = ref.watch(
      authProvider.select((state) => state.profile?.id),
    );
    final title = '댓글 ($_displayedCount)';

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _CommentsHeader(title: title, onBack: _goBack),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(post, currentUserId),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _CommentInputBar(
        controller: _controller,
        focusNode: _focusNode,
        submitting: _submitting,
        canSubmit: _controller.text.trim().isNotEmpty,
        onSubmit: _submit,
      ),
    );
  }

  Widget _buildContent(Post? post, String? currentUserId) {
    if (_errorText != null && _comments.isEmpty) {
      return Center(child: AppText(_errorText!, color: AppColors.muted));
    }
    if (_comments.isEmpty && _displayedCount == 0) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🐾', style: TextStyle(fontSize: 42)),
            SizedBox(height: 10),
            AppText('아직 댓글이 없어요', fontSize: 15, fontWeight: FontWeight.bold),
          ],
        ),
      );
    }

    return ListView(
      key: const Key('community-comments-list'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        for (final comment in _comments)
          CommunityCommentTile(
            comment: comment,
            canManage:
                post != null &&
                canManageCommunityComment(
                  currentUserId: currentUserId,
                  post: post,
                  comment: comment,
                ),
            onMore: () => showCommunityCommentMoreMenu(context),
          ),
        if (_nextCursor != null)
          TextButton(
            key: const Key('community-comments-load-more'),
            onPressed: _loadingMore ? null : _loadMore,
            child: _loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppText(
                    '더보기',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
          ),
      ],
    );
  }

  void _goBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Navigator.of(context).canPop()) {
      context.pop(true);
    } else {
      context.go(communityPostPath(widget.postId, widget.sourceKey));
    }
  }
}

class _CommentsHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _CommentsHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: IconButton(
            key: const Key('community-comments-back'),
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
        const SizedBox(width: 56, height: 56),
      ],
    ),
  );
}

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool submitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.submitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('community-comment-image-button'),
                    tooltip: '이미지 첨부',
                    onPressed: () => showPreparingToast(context),
                    icon: const Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('community-comments-input'),
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '댓글을 입력하세요',
                        filled: true,
                        fillColor: AppColors.surfaceSoft,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: const Key('community-comments-submit'),
                    onPressed: submitting || !canSubmit ? null : onSubmit,
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
          ],
        ),
      ),
    ),
  );
}
