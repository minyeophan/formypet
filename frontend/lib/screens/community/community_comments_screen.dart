import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_v2_tokens.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/preparing_toast.dart';
import 'community_comments_widgets.dart';
import 'community_routes.dart';

class CommunityCommentsScreen extends ConsumerStatefulWidget {
  const CommunityCommentsScreen({
    super.key,
    required this.postId,
    this.sourceKey,
    this.autofocus = false,
    this.initialThreadId,
    this.initialReplyToCommentId,
  });

  final String postId;
  final String? sourceKey;
  final bool autofocus;
  final String? initialThreadId;
  final String? initialReplyToCommentId;

  @override
  ConsumerState<CommunityCommentsScreen> createState() =>
      _CommunityCommentsScreenState();
}

class _CommunityCommentsScreenState
    extends ConsumerState<CommunityCommentsScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _threadKeys = {};
  final Set<String> _loadingReplies = {};

  List<PostComment> _comments = const [];
  String? _nextCursor;
  String? _replyToCommentId;
  String? _editingCommentId;
  final Set<String> _mutatingCommentIds = {};
  bool _initialLoading = true;
  bool _reloadLocked = false;
  bool _loadingMore = false;
  bool _submitting = false;
  bool _resolvingTarget = false;
  bool _postUnavailable = false;
  String? _firstPageError;
  int _displayedCount = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    _displayedCount =
        ref.read(communityProvider).postsById[widget.postId]?.commentsCount ??
        0;
    _replyToCommentId = widget.initialReplyToCommentId;
    _resolvingTarget = widget.initialThreadId != null;
    _reload();
    if (widget.autofocus && widget.initialThreadId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller.removeListener(_onInputChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    if (_reloadLocked) return;
    final generation = ++_generation;
    setState(() {
      _reloadLocked = true;
      _initialLoading = _comments.isEmpty;
      _firstPageError = null;
      _postUnavailable = false;
    });

    Post? post;
    PostCommentFeed? feed;
    Object? commentsError;
    Future<void> loadPost() async {
      try {
        post = await ref
            .read(communityProvider.notifier)
            .loadPost(widget.postId);
      } catch (_) {
        // Metadata failure does not prevent the comments API from rendering.
      }
    }

    Future<void> loadComments() async {
      try {
        feed = await ref
            .read(communityServiceProvider)
            .getComments(
              widget.postId,
              cursor: null,
              limit: 20,
              replyLimit: 20,
            );
      } catch (error) {
        commentsError = error;
      }
    }

    final postFuture = loadPost();
    final commentsFuture = loadComments();
    await Future.wait([postFuture, commentsFuture]);
    if (!mounted || generation != _generation) return;

    if (commentsError != null) {
      if (_comments.isNotEmpty) {
        _showError('댓글을 불러오지 못했습니다');
      } else if (_isUnavailable(commentsError!)) {
        _postUnavailable = true;
      } else {
        _firstPageError = '댓글을 불러오지 못했습니다';
      }
    } else if (feed != null) {
      _comments = _mergeRoots(const [], feed!.items);
      _nextCursor = feed!.nextCursor;
    }

    _displayedCount = _calculateCount(post);
    _reloadLocked = false;
    _initialLoading = false;
    setState(() {});
    if (!_postUnavailable && commentsError == null) {
      await _resolveInitialTarget(generation);
    } else {
      _resolvingTarget = false;
    }
  }

  Future<void> _resolveInitialTarget(int generation) async {
    final targetId = widget.initialThreadId;
    if (targetId == null) return;
    var root = _rootById(targetId);
    if (root == null) {
      try {
        final thread = await ref
            .read(communityServiceProvider)
            .getCommentThread(widget.postId, targetId, replyLimit: 20);
        if (!mounted || generation != _generation) return;
        if (thread.parentCommentId != null) throw const _InvalidTarget();
        _comments = _mergeRoots(_comments, [thread]);
        root = thread;
      } catch (error) {
        if (!mounted || generation != _generation) return;
        _replyToCommentId = null;
        _resolvingTarget = false;
        setState(() {});
        _showError(
          error is _InvalidTarget || _isUnavailable(error)
              ? '답글을 찾을 수 없습니다'
              : '답글을 불러오지 못했습니다',
        );
        return;
      }
    }
    if (!mounted || generation != _generation) return;
    _resolvingTarget = false;
    if (widget.initialReplyToCommentId != null && !root.deleted) {
      _replyToCommentId = root.id;
    }
    _displayedCount = _calculateCount(null);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      final targetContext = _threadKeys[root!.id]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 220),
        );
      }
      if (widget.initialReplyToCommentId != null && !root.deleted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final feed = await ref
          .read(communityServiceProvider)
          .getComments(
            widget.postId,
            cursor: cursor,
            limit: 20,
            replyLimit: 20,
          );
      if (!mounted || generation != _generation) return;
      _comments = _mergeRoots(_comments, feed.items);
      _nextCursor = feed.nextCursor;
      _displayedCount = _calculateCount(null);
    } catch (_) {
      if (mounted && generation == _generation) {
        _showError('댓글을 더 불러오지 못했습니다');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _loadEarlierReplies(PostComment root) async {
    final cursor = root.repliesNextCursor;
    if (cursor == null || _loadingReplies.contains(root.id)) return;
    final generation = _generation;
    setState(() => _loadingReplies.add(root.id));
    try {
      final feed = await ref
          .read(communityServiceProvider)
          .getReplies(widget.postId, root.id, cursor: cursor, limit: 20);
      if (!mounted || generation != _generation) return;
      _comments = _comments.map((item) {
        if (item.id != root.id) return item;
        final merged = _mergeRoot(item, item.copyWith(replies: feed.items));
        return merged.copyWith(
          repliesNextCursor: feed.nextCursor,
          clearRepliesNextCursor: feed.nextCursor == null,
        );
      }).toList();
      _displayedCount = _calculateCount(null);
    } catch (_) {
      if (mounted && generation == _generation) {
        _showError('답글을 더 불러오지 못했습니다');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingReplies.remove(root.id));
      }
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting || _resolvingTarget) return;
    final editingCommentId = _editingCommentId;
    if (editingCommentId != null) {
      await _submitEdit(editingCommentId, content);
      return;
    }
    final replyTarget = _replyToCommentId;
    if (replyTarget != null && _rootById(replyTarget)?.deleted == true) {
      setState(() => _replyToCommentId = null);
      return;
    }
    setState(() => _submitting = true);
    try {
      final comment = await ref
          .read(communityProvider.notifier)
          .createComment(widget.postId, content, parentCommentId: replyTarget);
      if (!mounted) return;
      final exists = _containsComment(comment.id);
      if (!exists && replyTarget == null) {
        _comments = _mergeRoots([comment], _comments);
      } else if (!exists && replyTarget != null) {
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
      _displayedCount = max(
        comment.commentsCount,
        exists ? _displayedCount : _displayedCount + 1,
      );
      _controller.clear();
      _replyToCommentId = null;
      _focusNode.requestFocus();
      setState(() => _submitting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('댓글을 등록하지 못했습니다');
    }
  }

  Future<void> _submitEdit(String commentId, String content) async {
    if (_mutatingCommentIds.contains(commentId)) return;
    setState(() {
      _submitting = true;
      _mutatingCommentIds.add(commentId);
    });
    try {
      final updated = await ref
          .read(communityProvider.notifier)
          .updateComment(widget.postId, commentId, content);
      if (!mounted) return;
      setState(() {
        _comments = _replaceComment(_comments, updated);
        _resetComposer();
        _submitting = false;
        _mutatingCommentIds.remove(commentId);
      });
      _focusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _mutatingCommentIds.remove(commentId);
      });
      _showError('댓글을 수정하지 못했습니다');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityProvider);
    final post = state.postsById[widget.postId];
    final currentUserId = ref.watch(
      authProvider.select((value) => value.profile?.id),
    );
    final showContent = !_postUnavailable;
    final replyRoot = _replyToCommentId == null
        ? null
        : _rootById(_replyToCommentId!);

    return Scaffold(
      backgroundColor: AppV2Tokens.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CommunityCommentsHeader(
              title: '댓글 ($_displayedCount)',
              onBack: _goBack,
              onMore: showContent ? () => showPreparingToast(context) : null,
            ),
            Expanded(child: _buildContent(post, currentUserId)),
          ],
        ),
      ),
      bottomNavigationBar: showContent
          ? CommunityCommentsComposer(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !_resolvingTarget,
              canSubmit:
                  _controller.text.trim().isNotEmpty &&
                  !_resolvingTarget &&
                  !_submitting,
              submitting: _submitting,
              replyTo: replyRoot?.deleted == true
                  ? null
                  : replyRoot?.authorNickname,
              editing: _editingCommentId != null,
              onCancelReply: () => setState(_resetComposer),
              onSubmit: _submit,
            )
          : null,
    );
  }

  Widget _buildContent(Post? post, String? currentUserId) {
    if (_postUnavailable) {
      return const ColoredBox(
        color: AppV2Tokens.background,
        child: CommunityCommentsStatus(message: '게시글을 찾을 수 없습니다'),
      );
    }
    if (_initialLoading) {
      return const ColoredBox(
        color: AppV2Tokens.background,
        child: CommunityCommentsStatus(message: '', loading: true),
      );
    }
    if (_firstPageError != null && _comments.isEmpty) {
      return ColoredBox(
        color: AppV2Tokens.background,
        child: CommunityCommentsStatus(
          message: _firstPageError!,
          onRetry: _reload,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: ListView(
          key: const Key('community-comments-list'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            CommunityCommentsSortRow(
              onPopular: () => showPreparingToast(context),
            ),
            const SizedBox(height: 12),
            if (_comments.isEmpty)
              const SizedBox(
                height: 260,
                child: CommunityCommentsStatus(
                  message: '아직 댓글이 없어요',
                  empty: true,
                ),
              )
            else
              for (var i = 0; i < _comments.length; i++) ...[
                if (i > 0) const SizedBox(height: 24),
                CommunityCommentGroup(
                  threadKey: _threadKeys.putIfAbsent(
                    _comments[i].id,
                    GlobalKey.new,
                  ),
                  root: _comments[i],
                  onRootMore: () =>
                      _showCommentMenu(_comments[i], post, currentUserId),
                  onReply: () => _startReply(_comments[i]),
                  onReplyMore: (reply) =>
                      _showCommentMenu(reply, post, currentUserId),
                  onLoadEarlierReplies: _comments[i].repliesNextCursor == null
                      ? null
                      : () => _loadEarlierReplies(_comments[i]),
                  loadingReplies: _loadingReplies.contains(_comments[i].id),
                ),
              ],
            if (_nextCursor != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: TextButton(
                  key: const Key('community-comments-load-more'),
                  onPressed: _loadingMore ? null : _loadMore,
                  child: _loadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('더보기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCommentMenu(
    PostComment comment,
    Post? post,
    String? currentUserId,
  ) async {
    if (comment.deleted) return;
    if (_mutatingCommentIds.contains(comment.id)) return;
    final kind = currentUserId != null && comment.userId == currentUserId
        ? CommunityCommentMenuKind.commentOwner
        : currentUserId != null && post?.userId == currentUserId
        ? CommunityCommentMenuKind.postOwner
        : CommunityCommentMenuKind.viewer;
    final action = await showCommunityCommentsV2Menu(context, kind: kind);
    if (!mounted || action == null) return;
    switch (action) {
      case CommunityCommentMenuAction.edit:
        _startEdit(comment);
        break;
      case CommunityCommentMenuAction.delete:
        await _confirmAndDelete(comment);
        break;
      case CommunityCommentMenuAction.report:
      case CommunityCommentMenuAction.block:
        showPreparingToast(context);
        break;
    }
  }

  void _startReply(PostComment root) {
    if (root.deleted) return;
    setState(() {
      _editingCommentId = null;
      _replyToCommentId = root.id;
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  void _startEdit(PostComment comment) {
    setState(() {
      _replyToCommentId = null;
      _editingCommentId = comment.id;
      _controller.text = comment.content;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  Future<void> _confirmAndDelete(PostComment comment) async {
    final confirmed = await showCommunityCommentDeleteConfirmationSheet(context);
    if (!mounted || confirmed != true) return;
    await _deleteComment(comment);
  }

  Future<void> _deleteComment(PostComment comment) async {
    if (_mutatingCommentIds.contains(comment.id)) return;
    setState(() => _mutatingCommentIds.add(comment.id));
    try {
      await ref
          .read(communityProvider.notifier)
          .deleteComment(widget.postId, comment.id);
      if (!mounted) return;
      setState(() {
        _comments = _deleteCommentLocally(_comments, comment);
        _comments = _withCommentCounts(_comments, max(0, _displayedCount - 1));
        _displayedCount = max(0, _displayedCount - 1);
        if (_replyToCommentId == comment.id || _editingCommentId == comment.id) {
          _resetComposer();
        }
        _mutatingCommentIds.remove(comment.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _mutatingCommentIds.remove(comment.id));
      _showError('댓글을 삭제하지 못했습니다');
    }
  }

  void _resetComposer() {
    _replyToCommentId = null;
    _editingCommentId = null;
    _controller.clear();
  }

  PostComment? _rootById(String id) {
    for (final root in _comments) {
      if (root.id == id) return root;
    }
    return null;
  }

  int _calculateCount(Post? post) {
    final cached = ref.read(communityProvider).postsById[widget.postId];
    final responseCount = _comments.fold<int>(
      0,
      (count, root) => max(count, root.commentsCount),
    );
    return max(
      max(post?.commentsCount ?? cached?.commentsCount ?? 0, responseCount),
      _loadedCommentCount(),
    );
  }

  int _loadedCommentCount() => _comments.fold<int>(0, (count, root) {
    final rootCount = root.deleted ? 0 : 1;
    final repliesCount = root.replies
        .where((reply) => !reply.deleted)
        .map((reply) => reply.id)
        .toSet()
        .length;
    return count + rootCount + repliesCount;
  });

  bool _containsComment(String id) => _comments.any(
    (root) => root.id == id || root.replies.any((reply) => reply.id == id),
  );

  List<PostComment> _replaceComment(
    List<PostComment> comments,
    PostComment updated,
  ) {
    return comments.map((root) {
      if (root.id == updated.id) {
        return _mergeCommentScalars(root, updated);
      }
      return root.copyWith(
        replies: root.replies
            .map(
              (reply) => reply.id == updated.id
                  ? _mergeCommentScalars(reply, updated)
                  : reply,
            )
            .toList(),
      );
    }).toList();
  }

  PostComment _mergeCommentScalars(
    PostComment current,
    PostComment updated,
  ) {
    return current.copyWith(
      content: updated.content,
      updatedAt: updated.updatedAt,
      deleted: updated.deleted,
      commentsCount: updated.commentsCount,
    );
  }

  List<PostComment> _deleteCommentLocally(
    List<PostComment> comments,
    PostComment target,
  ) {
    final parentRootId =
        target.parentCommentId ?? _parentRootId(comments, target);
    if (parentRootId != null) {
      return comments
          .map((root) {
            if (root.id != parentRootId) return root;
            final replies = root.replies
                .where((reply) => reply.id != target.id)
                .toList();
            final next = root.copyWith(
              replies: replies,
              replyCount: max(0, root.replyCount - 1),
            );
            if (next.deleted &&
                replies.where((reply) => !reply.deleted).isEmpty &&
                next.repliesNextCursor == null) {
              return null;
            }
            return next;
          })
          .whereType<PostComment>()
          .toList();
    }

    return comments
        .map((root) {
          if (root.id != target.id) return root;
          final hasActiveLoadedReplies = root.replies.any(
            (reply) => !reply.deleted,
          );
          final shouldKeepTombstone =
              hasActiveLoadedReplies ||
              root.replyCount > 0 ||
              root.repliesNextCursor != null;
          if (!shouldKeepTombstone) return null;
          return _tombstoneRoot(root);
        })
        .whereType<PostComment>()
        .toList();
  }

  String? _parentRootId(List<PostComment> comments, PostComment target) {
    for (final root in comments) {
      if (root.replies.any((reply) => reply.id == target.id)) return root.id;
    }
    return null;
  }

  PostComment _tombstoneRoot(PostComment root) {
    return PostComment(
      id: root.id,
      userId: '',
      authorNickname: '',
      content: '',
      createdAt: root.createdAt,
      updatedAt: root.updatedAt,
      deleted: true,
      commentsCount: max(0, _displayedCount - 1),
      parentCommentId: root.parentCommentId,
      replyCount: root.replyCount,
      replies: root.replies,
      repliesNextCursor: root.repliesNextCursor,
    );
  }

  List<PostComment> _withCommentCounts(
    List<PostComment> comments,
    int commentsCount,
  ) {
    return comments
        .map(
          (root) => root.copyWith(
            commentsCount: commentsCount,
            replies: root.replies
                .map((reply) => reply.copyWith(commentsCount: commentsCount))
                .toList(),
          ),
        )
        .toList();
  }

  List<PostComment> _mergeRoots(
    List<PostComment> current,
    List<PostComment> incoming,
  ) {
    final byId = <String, PostComment>{
      for (final root in current) root.id: root,
    };
    for (final root in incoming.where((item) => item.parentCommentId == null)) {
      byId[root.id] = byId[root.id] == null
          ? root
          : _mergeRoot(byId[root.id]!, root);
    }
    return byId.values.toList()..sort((a, b) => _compareIds(b.id, a.id));
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
    return incoming.copyWith(
      replies: replies,
      replyCount: replyCount,
      commentsCount: max(current.commentsCount, incoming.commentsCount),
      repliesNextCursor:
          incoming.repliesNextCursor ?? current.repliesNextCursor,
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

  bool _isUnavailable(Object error) =>
      error is DioException &&
      (error.response?.statusCode == 400 || error.response?.statusCode == 404);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

class _InvalidTarget implements Exception {
  const _InvalidTarget();
}
