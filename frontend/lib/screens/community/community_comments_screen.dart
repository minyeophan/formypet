import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

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
  final String? initialThreadId;
  final String? initialReplyToCommentId;

  const CommunityCommentsScreen({
    super.key,
    required this.postId,
    this.sourceKey,
    this.autofocus = false,
    this.initialThreadId,
    this.initialReplyToCommentId,
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
  String? _replyToCommentId;
  bool _resolvingTarget = false;
  final Set<String> _loadingReplies = {};
  final Map<String, GlobalKey> _threadKeys = {};
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    final cached = ref.read(communityProvider).postsById[widget.postId];
    _displayedCount = cached?.commentsCount ?? 0;
    _replyToCommentId = widget.initialReplyToCommentId;
    _resolvingTarget = widget.initialThreadId != null;
    _load();
    if (widget.autofocus && widget.initialThreadId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
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
    final generation = ++_requestGeneration;
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
      _comments = _mergeRoots(_comments, feed.items);
      _nextCursor = feed.nextCursor;
    } catch (error) {
      commentsError = error;
    }

    await postFuture;

    final targetId = widget.initialThreadId;
    if (targetId != null && !_comments.any((item) => item.id == targetId)) {
      try {
        final thread = await ref
            .read(communityServiceProvider)
            .getCommentThread(widget.postId, targetId);
        if (!mounted || generation != _requestGeneration) return;
        _comments = _mergeRoots([thread], _comments);
      } on DioException catch (error) {
        if (!mounted || generation != _requestGeneration) return;
        final status = error.response?.statusCode;
        _errorText = status == 400 || status == 404
            ? '답글을 찾을 수 없습니다'
            : '답글을 불러오지 못했습니다';
        _replyToCommentId = null;
      } catch (_) {
        if (!mounted || generation != _requestGeneration) return;
        _errorText = '답글을 불러오지 못했습니다';
        _replyToCommentId = null;
      }
    }

    if (!mounted || generation != _requestGeneration) return;
    _resolvingTarget = false;

    final cached = ref.read(communityProvider).postsById[widget.postId];
    final baseCount =
        refreshedPost?.commentsCount ?? cached?.commentsCount ?? 0;
    final responseCount = _comments.fold<int>(
      0,
      (value, comment) => max(value, comment.commentsCount),
    );
    _displayedCount = max(
      max(baseCount, responseCount),
      _loadedCommentCount(),
    );
    if (commentsError != null && _comments.isEmpty) {
      _errorText = '댓글을 불러오지 못했습니다';
    }
    setState(() => _loading = false);
    if (targetId != null && _comments.any((item) => item.id == targetId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _requestGeneration) return;
        final context = _threadKeys[targetId]?.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 220),
          );
        }
        if (widget.autofocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final feed = await ref
          .read(communityServiceProvider)
          .getComments(widget.postId, cursor: cursor, limit: 20);
      _comments = _mergeRoots(_comments, feed.items);
      _nextCursor = feed.nextCursor;
      _displayedCount = max(_displayedCount, _loadedCommentCount());
    } catch (_) {
      // Preserve the existing page and cursor so the user can retry.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting || _resolvingTarget) return;
    setState(() => _submitting = true);
    try {
      final comment = await ref
          .read(communityProvider.notifier)
          .createComment(
            widget.postId,
            content,
            parentCommentId: _replyToCommentId,
          );
      if (!mounted) return;
      final replyTarget = _replyToCommentId;
      final exists = _containsComment(comment.id);
      if (replyTarget == null && !exists) {
        _comments = [comment, ..._comments];
      } else if (replyTarget != null && !exists) {
        _comments = _comments.map((root) {
          if (root.id != replyTarget) return root;
          return _mergeRoot(
            root,
            root.copyWith(
              replies: [...root.replies, comment],
              replyCount: root.replyCount + 1,
            ),
          );
        }).toList();
      }
      final inserted = exists ? 0 : 1;
      _displayedCount = max(_displayedCount + inserted, comment.commentsCount);
      _controller.clear();
      _replyToCommentId = null;
      _focusNode.requestFocus();
      setState(() => _submitting = false);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _containsComment(String id) => _comments.any(
    (root) => root.id == id || root.replies.any((reply) => reply.id == id),
  );

  int _loadedCommentCount() => _comments.fold<int>(
    0,
    (count, root) =>
        count + 1 + root.replies.map((reply) => reply.id).toSet().length,
  );

  List<PostComment> _mergeRoots(
    List<PostComment> current,
    List<PostComment> incoming,
  ) {
    final byId = <String, PostComment>{
      for (final root in current) root.id: root,
    };
    for (final root in incoming) {
      byId[root.id] = byId[root.id] == null
          ? root
          : _mergeRoot(byId[root.id]!, root);
    }
    final result = byId.values.toList();
    result.sort((a, b) => _compareIds(b.id, a.id));
    return result;
  }

  PostComment _mergeRoot(PostComment current, PostComment incoming) {
    final replies = <String, PostComment>{
      for (final reply in current.replies) reply.id: reply,
      for (final reply in incoming.replies) reply.id: reply,
    }.values.toList()..sort((a, b) => _compareIds(a.id, b.id));
    final replyCount = max(
      max(current.replyCount, incoming.replyCount),
      replies.length,
    );
    final commentsCount = max(
      max(current.commentsCount, incoming.commentsCount),
      _displayedCount,
    );
    return incoming.copyWith(
      replies: replies,
      replyCount: replyCount,
      commentsCount: commentsCount,
      repliesNextCursor: replyCount > replies.length && replies.isNotEmpty
          ? replies.first.id
          : null,
      clearRepliesNextCursor: replyCount <= replies.length,
    );
  }

  int _compareIds(String a, String b) {
    final left = int.tryParse(a);
    final right = int.tryParse(b);
    return left != null && right != null
        ? left.compareTo(right)
        : a.compareTo(b);
  }

  Future<void> _loadEarlierReplies(PostComment root) async {
    if (_loadingReplies.contains(root.id) || root.repliesNextCursor == null) {
      return;
    }
    setState(() => _loadingReplies.add(root.id));
    try {
      final feed = await ref
          .read(communityServiceProvider)
          .getReplies(widget.postId, root.id, cursor: root.repliesNextCursor);
      if (!mounted) return;
      _comments = _comments.map((item) {
        if (item.id != root.id) return item;
        final merged = _mergeRoot(item, item.copyWith(replies: feed.items));
        return merged.copyWith(
          repliesNextCursor: merged.replyCount > merged.replies.length
              ? merged.replies.first.id
              : null,
          clearRepliesNextCursor: merged.replyCount <= merged.replies.length,
        );
      }).toList();
    } catch (_) {
      // Preserve replies and cursor so the same button remains retryable.
    } finally {
      if (mounted) setState(() => _loadingReplies.remove(root.id));
    }
  }

  void _startReply(PostComment root) {
    setState(() => _replyToCommentId = root.id);
    _focusNode.requestFocus();
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
        canSubmit: _controller.text.trim().isNotEmpty && !_resolvingTarget,
        enabled: !_resolvingTarget,
        replyTo: _replyToCommentId == null
            ? null
            : _comments
                  .where((item) => item.id == _replyToCommentId)
                  .firstOrNull
                  ?.authorNickname,
        onCancelReply: () => setState(() => _replyToCommentId = null),
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
        for (final comment in _comments) ...[
          CommunityCommentTile(
            key: _threadKeys.putIfAbsent(comment.id, GlobalKey.new),
            comment: comment,
            canManage:
                post != null &&
                canManageCommunityComment(
                  currentUserId: currentUserId,
                  post: post,
                  comment: comment,
                ),
            onMore: () => showCommunityCommentMoreMenu(context),
            onReply: () => _startReply(comment),
          ),
          if (comment.repliesNextCursor != null)
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: TextButton(
                key: Key('community-replies-load-more-${comment.id}'),
                onPressed: _loadingReplies.contains(comment.id)
                    ? null
                    : () => _loadEarlierReplies(comment),
                child: AppText('이전 답글 더보기', fontSize: 12),
              ),
            ),
          for (final reply in comment.replies)
            CommunityCommentTile(
              comment: reply,
              isReply: true,
              canManage:
                  post != null &&
                  canManageCommunityComment(
                    currentUserId: currentUserId,
                    post: post,
                    comment: reply,
                  ),
              onMore: () => showCommunityCommentMoreMenu(context),
            ),
        ],
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
  final bool enabled;
  final String? replyTo;
  final VoidCallback onCancelReply;

  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.submitting,
    required this.canSubmit,
    required this.onSubmit,
    required this.enabled,
    required this.replyTo,
    required this.onCancelReply,
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
            if (replyTo != null)
              Row(
                key: const Key('community-reply-composer-target'),
                children: [
                  const SizedBox(width: 16),
                  Expanded(child: AppText('$replyTo님에게 답글', fontSize: 12)),
                  IconButton(
                    key: const Key('community-reply-cancel'),
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
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
                      enabled: enabled,
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
