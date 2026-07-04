import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_v2_tokens.dart';
import '../../core/keyboard_utils.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_more_button.dart';
import '../../widgets/preparing_toast.dart';
import 'community_comment_widgets.dart';
import 'community_constants.dart';
import 'community_detail_widgets.dart';
import 'community_routes.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({
    super.key,
    required this.postId,
    this.sourceKey,
  });
  final String postId;
  final String? sourceKey;
  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  final _scrollController = ScrollController();
  List<PostComment> _comments = const [];
  String? _commentsCursor;
  Object? _commentsError;
  bool _unavailable = false;
  bool _postLoading = true;
  bool _commentsLoading = true;
  bool _reloading = false;
  bool _voting = false;
  int _postGeneration = 0;
  int _commentsGeneration = 0;

  bool get _postMutationLocked =>
      _postLoading ||
      _voting ||
      ref.read(communityProvider).isLiking(widget.postId);

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_reloading) return;
    _reloading = true;
    try {
      await Future.wait<void>([_loadPost(), _loadComments()]);
    } finally {
      _reloading = false;
    }
  }

  Future<void> _loadPost() async {
    final generation = ++_postGeneration;
    if (mounted) {
      setState(() {
        _postLoading = true;
        _unavailable = false;
      });
    }
    try {
      await ref.read(communityProvider.notifier).loadPost(widget.postId);
    } catch (error) {
      if (!mounted || generation != _postGeneration) return;
      final status = error is DioException ? error.response?.statusCode : null;
      setState(() {
        if (status == 400 || status == 404) {
          _unavailable = true;
        }
      });
      if (ref.read(communityProvider).postsById[widget.postId] != null &&
          status != 400 &&
          status != 404) {
        _snack('게시글을 불러오지 못했습니다');
      }
    } finally {
      if (mounted && generation == _postGeneration) {
        setState(() => _postLoading = false);
      }
    }
  }

  Future<void> _loadComments() async {
    final generation = ++_commentsGeneration;
    if (mounted) {
      setState(() {
        _commentsLoading = true;
        _commentsError = null;
      });
    }
    try {
      final feed = await ref
          .read(communityServiceProvider)
          .getComments(widget.postId, limit: 3, replyLimit: 2);
      if (!mounted || generation != _commentsGeneration) return;
      final roots = <String, PostComment>{};
      for (final item in feed.items) {
        if (roots.length == 3 && !roots.containsKey(item.id)) continue;
        final replies = <String, PostComment>{
          for (final reply in item.replies) reply.id: reply,
        }.values.take(2).toList();
        roots[item.id] = item.copyWith(replies: replies);
      }
      setState(() {
        _comments = roots.values.toList();
        _commentsCursor = feed.nextCursor;
      });
    } catch (error) {
      if (!mounted || generation != _commentsGeneration) return;
      setState(() => _commentsError = error);
    } finally {
      if (mounted && generation == _commentsGeneration) {
        setState(() => _commentsLoading = false);
      }
    }
  }

  Future<void> _toggleLike(Post post) async {
    if (_postMutationLocked) return;
    try {
      await ref.read(communityProvider.notifier).toggleLike(post.id);
    } catch (_) {
      if (mounted) _snack('좋아요를 처리하지 못했습니다');
    }
  }

  Future<void> _vote(String optionId) async {
    if (_postMutationLocked) return;
    setState(() => _voting = true);
    try {
      await ref.read(communityProvider.notifier).vote(widget.postId, optionId);
    } catch (_) {
      if (mounted) _snack('투표를 처리하지 못했습니다');
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _openComments({
    bool focus = false,
    String? threadId,
    String? replyToCommentId,
  }) async {
    await dismissKeyboardBeforeTransition(context);
    if (!mounted) return;
    await context.push(
      communityCommentsPath(
        widget.postId,
        widget.sourceKey,
        focus: focus,
        threadId: threadId,
        replyToCommentId: replyToCommentId,
      ),
    );
    if (mounted) await _reload();
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityProvider);
    final post = state.postsById[widget.postId];
    final currentUserId = ref.watch(
      authProvider.select((value) => value.profile?.id),
    );
    final visible = post != null && !_unavailable;
    return Scaffold(
      backgroundColor: AppV2Tokens.background,
      body: SafeArea(
        child: Column(
          children: [
            _DetailHeader(
              title: _headerTitle(post),
              onBack: _goBack,
              onMore: visible ? _showPostMoreMenu : null,
            ),
            Expanded(child: _buildBody(post, currentUserId)),
          ],
        ),
      ),
      bottomNavigationBar: visible
          ? _CommentLauncher(onPressed: () => _openComments(focus: true))
          : null,
    );
  }

  Widget _buildBody(Post? post, String? currentUserId) {
    if (_unavailable) return _MessageState(message: '게시글을 찾을 수 없습니다');
    if (post == null && _postLoading) return const CommunityDetailSkeleton();
    if (post == null) {
      return _MessageState(
        message: '게시글을 불러오지 못했습니다',
        actionLabel: '재시도',
        onAction: _reload,
      );
    }
    final loadedUnique = _comments.fold<int>(
      0,
      (sum, root) => sum + 1 + root.replies.map((e) => e.id).toSet().length,
    );
    final responseTotal = _comments.fold<int>(
      0,
      (sum, root) => sum + 1 + root.replyCount,
    );
    final total = [
      post.commentsCount,
      responseTotal,
      loadedUnique,
    ].reduce((a, b) => a > b ? a : b);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: ListView(
          key: const Key('community-detail-scroll'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            CommunityDetailArticle(
              post: post,
              onLike: () => _toggleLike(post),
              likeEnabled: !_postMutationLocked,
              onVote: _vote,
              voteBusy: _voting,
              commentsCount: total,
            ),
            if (_commentsLoading && _comments.isEmpty)
              const CommunityCommentSkeleton()
            else
              CommunityCommentPreview(
                post: post,
                comments: _comments,
                currentUserId: currentUserId,
                total: total,
                hasMore: _commentsCursor != null,
                onMore: () => _openComments(),
                onReply: (id) =>
                    _openComments(focus: true, replyToCommentId: id),
                onThread: (id) => _openComments(threadId: id),
                onManage: () => showCommunityCommentMoreMenu(context),
              ),
            if (_commentsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '댓글을 불러오지 못했습니다',
                        style: communityV2Style(
                          size: 13,
                          color: AppV2Tokens.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadComments,
                      child: const Text('재시도'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _headerTitle(Post? post) {
    final source = communitySourceLabel(widget.sourceKey);
    if (source.isNotEmpty) return source;
    final category = communitySourceLabel(post?.category);
    return category.isNotEmpty ? category : '게시글';
  }

  void _goBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(communityFallbackPath(widget.sourceKey));
    }
  }

  void _showPostMoreMenu() => showAppActionSheet(
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

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.onBack, this.onMore});
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onMore;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: Padding(
      padding: const EdgeInsets.only(left: 20, right: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: const Key('community-detail-back'),
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppV2Tokens.text,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: communityV2Style(size: 24, weight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: onMore == null
                ? null
                : AppMoreButton.plain(
                    key: const Key('community-detail-more-button'),
                    onPressed: onMore,
                    plainColor: AppV2Tokens.textSecondary,
                    plainSplashColor: AppV2Tokens.primarySoft,
                  ),
          ),
        ],
      ),
    ),
  );
}

class _CommentLauncher extends StatefulWidget {
  const _CommentLauncher({required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<_CommentLauncher> createState() => _CommentLauncherState();
}

class _CommentLauncherState extends State<_CommentLauncher> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: AppV2Tokens.background,
      child: Container(
        key: const Key('community-detail-launcher-shell'),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppV2Tokens.border)),
        ),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Container(
          key: _focused ? const Key('community-detail-launcher-focus') : null,
          decoration: _focused
              ? BoxDecoration(
                  border: Border.all(color: AppV2Tokens.primary, width: 2),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: InkWell(
            key: const Key('community-detail-comment-launcher'),
            onTap: widget.onPressed,
            onFocusChange: (focused) => setState(() => _focused = focused),
            splashColor: AppV2Tokens.primarySoft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '소중한 댓글을 남겨주세요',
                    style: communityV2Style(
                      size: 14,
                      color: AppV2Tokens.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: AppV2Tokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: communityV2Style(size: 15)),
        if (onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}
